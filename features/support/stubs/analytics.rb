# frozen_string_literal: true

def stub_ga4(active_users: 10, page_views: 100, raise_error: false)
  if raise_error
    allow(Analytics::Metrics).to receive(:ga4_report).and_raise(StandardError, "GA4 unavailable")
  else
    allow(Analytics::Metrics).to receive(:ga4_report).and_return(
      { "active_users" => active_users, "page_views" => page_views }
    )
  end
end

def stub_formspree(count:)
  allow(Analytics::Metrics).to receive(:formspree_count).and_return(count)
end
