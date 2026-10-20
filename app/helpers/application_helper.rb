# frozen_string_literal: true

module ApplicationHelper
  def nav_link_class(key)
    base = "hover:underline underline-offset-4"
    current_nav == key ? "#{base} font-semibold underline" : base
  end

  def mobile_tab_class(key)
    current_nav == key ? "font-semibold text-[var(--ink)]" : "text-[var(--muted)]"
  end
end
