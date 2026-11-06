# frozen_string_literal: true

module ApplicationHelper
  def stepper_step(label, key, complete, path)
    active = current_nav == key
    classes = active ? "font-semibold text-[var(--ink)]" : "text-[var(--muted)]"
    tag.div(class: "flex items-center gap-1 #{classes}",
            data: { stepper_step: label.downcase, complete: complete.to_s }) do
      concat link_to(label, path, class: "hover:underline underline-offset-4")
      concat tag.span("✓", class: "text-green-600 text-xs") if complete
    end
  end

  def nav_link_class(key)
    base = "hover:underline underline-offset-4"
    current_nav == key ? "#{base} font-semibold underline" : base
  end

  def mobile_tab_class(key)
    current_nav == key ? "font-semibold text-[var(--ink)]" : "text-[var(--muted)]"
  end
end
