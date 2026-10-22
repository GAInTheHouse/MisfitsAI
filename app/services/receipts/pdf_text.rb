# frozen_string_literal: true

require "timeout"
require "zlib"

module Receipts
  # Text of a receipt PDF (design doc 6.12 "pdf_text_rules"): the first 20 pages, joined by newlines.
  # Runs inside the request, so it is bounded on every axis:
  # - the file is at most 10 MB (checked by the controller before this runs);
  # - at most MAX_PAGES pages are read, and at most MAX_CHARS characters are returned;
  # - before a page's text is extracted, its content streams (and form XObjects) are inflated in small chunks
  #   against a shared MAX_INFLATED_BYTES budget, so a compression bomb is refused before pdf-reader inflates
  #   it whole into memory;
  # - the whole read is limited to TIMEOUT seconds.
  #
  #   PdfText.call(io) # => String; raises Receipts::UnreadableError
  class PdfText
    MAX_PAGES = 20
    MAX_CHARS = 50_000 # the parser only needs the line items
    MAX_INFLATED_BYTES = 20.megabytes # page content of a receipt is a few KB
    INFLATE_CHUNK = 4.kilobytes # one chunk inflates to at most ~4 MB (zlib's ratio is ~1:1000)
    TIMEOUT = 5 # seconds

    UNREADABLE = "We couldn't read that PDF. Try pasting the receipt text instead."
    TOO_COMPLEX = "That PDF is too large or complex to read. Try pasting the receipt text instead."

    class ReadTimeout < StandardError; end
    class ContentTooLarge < StandardError; end

    def self.call(io)
      new.call(io)
    end

    def call(io)
      Timeout.timeout(TIMEOUT, ReadTimeout) do
        reader = PDF::Reader.new(io)
        @budget = MAX_INFLATED_BYTES
        pages = (1..[ reader.page_count, MAX_PAGES ].min).map do |number|
          page = reader.page(number)
          check_inflated_size!(page)
          page.text
        end
        pages.join("\n").first(MAX_CHARS)
      end
    rescue ReadTimeout, ContentTooLarge => e
      raise UnreadableError.new(TOO_COMPLEX, e.class.name)
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, PDF::Reader::EncryptedPDFError,
           ArgumentError, NoMethodError, TypeError => e # pdf-reader raises these on some damaged files
      raise UnreadableError.new(UNREADABLE, e.class.name)
    end

    private

    def check_inflated_size!(page)
      streams_of(page).each do |stream|
        @budget -= inflated_size(stream, @budget)
        raise ContentTooLarge, "page content over #{MAX_INFLATED_BYTES} bytes" if @budget.negative?
      end
    end

    # The page's content streams, as pdf-reader's Page#raw_content finds them, plus its form XObjects.
    def streams_of(page)
      objects = page.objects
      contents = [ objects.deref_stream_or_array(page.page_object[:Contents]) ].flatten.compact
      forms = page.xobjects.values.map { objects.deref(_1) }.select { _1.is_a?(PDF::Reader::Stream) && _1.hash[:Subtype] == :Form }
      contents.filter_map { objects.deref_stream(_1) } + forms
    end

    # Bytes the stream will take once decoded, counting at most limit + 1 so a bomb stops early.
    def inflated_size(stream, limit)
      data = stream.data.to_s
      return data.bytesize unless Array(stream.hash[:Filter]).include?(:FlateDecode)

      inflater = Zlib::Inflate.new
      total = 0
      (0...data.bytesize).step(INFLATE_CHUNK) do |offset|
        total += inflater.inflate(data.byteslice(offset, INFLATE_CHUNK)).bytesize
        break if total > limit
      end
      total
    rescue Zlib::Error
      data.bytesize # damaged data: pdf-reader decides what to do with it
    ensure
      inflater&.close
    end
  end
end
