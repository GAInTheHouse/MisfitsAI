# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipts::PdfText do
  # A one-page PDF whose content stream is the given bytes, Flate-compressed when compress is true.
  def pdf_with_content(content, compress: true)
    stream = compress ? Zlib::Deflate.deflate(content) : content
    filter = compress ? " /Filter /FlateDecode" : ""
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
      "<< /Length #{stream.bytesize}#{filter} >>\nstream\n#{stream}\nendstream",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    ]
    pdf = +"%PDF-1.4\n".b
    offsets = objects.each_with_index.map { |obj, i| pdf.bytesize.tap { pdf << "#{i + 1} 0 obj\n#{obj}\nendobj\n".b } }
    xref = pdf.bytesize
    pdf << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { pdf << format("%010d 00000 n \n", _1) }
    pdf << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
    StringIO.new(pdf)
  end

  it "returns the text of the receipt PDF" do
    text = described_class.call(File.open(Rails.root.join("spec/fixtures/files/receipt.pdf")))
    expect(text).to include("Oxford Shirt White M $39.90", "Slim Fit Chinos Khaki 32 $49.90")
  end

  it "reads at most the first 20 pages (design doc 6.12)" do
    page = PDF::Reader.new(pdf_with_content("BT ET")).page(1) # a real page, built before stubbing new
    reader = instance_double(PDF::Reader, page_count: 25)
    allow(PDF::Reader).to receive(:new).and_return(reader)
    allow(reader).to receive(:page).and_return(page)
    described_class.call(StringIO.new("x"))
    expect(reader).to have_received(:page).exactly(20).times
  end

  it "reads a normal compressed content stream" do
    text = described_class.call(pdf_with_content("BT /F1 12 Tf 72 720 Td (Linen Shirt $30.00) Tj ET"))
    expect(text).to include("Linen Shirt $30.00")
  end

  it "refuses a compression bomb before inflating it whole (a few KB that would decode to 30 MB)" do
    bomb = pdf_with_content(" " * 30.megabytes)
    expect(bomb.size).to be < 100.kilobytes
    expect_any_instance_of(PDF::Reader::Page).not_to receive(:text)
    expect { described_class.call(bomb) }
      .to raise_error(Receipts::UnreadableError) { expect(_1.user_message).to include("too large or complex") }
  end

  it "counts the inflation budget across pages, not per page" do
    stub_const("#{described_class}::MAX_INFLATED_BYTES", 1_000)
    expect { described_class.call(pdf_with_content(" " * 2_000)) }.to raise_error(Receipts::UnreadableError)
    expect(described_class.call(pdf_with_content("BT ET"))).to eq("")
  end

  it "stops a read that takes longer than the timeout" do
    stub_const("#{described_class}::TIMEOUT", 0.2)
    allow_any_instance_of(PDF::Reader::Page).to receive(:text) { sleep 2 }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect { described_class.call(pdf_with_content("BT ET")) }
      .to raise_error(Receipts::UnreadableError) { expect(_1.user_message).to include("too large or complex") }
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.5
  end

  it "returns at most 50,000 characters" do
    allow_any_instance_of(PDF::Reader::Page).to receive(:text).and_return("x" * 60_000)
    expect(described_class.call(pdf_with_content("BT ET")).length).to eq(50_000)
  end

  [ "not a pdf", "%PDF-1.4\n%%EOF" ].each do |bytes|
    it "turns a damaged PDF (#{bytes.inspect}) into a friendly error" do
      expect { described_class.call(StringIO.new(bytes)) }
        .to raise_error(Receipts::UnreadableError) { expect(_1.user_message).to include("We couldn't read that PDF") }
    end
  end
end
