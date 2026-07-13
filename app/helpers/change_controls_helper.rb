module ChangeControlsHelper
  # Attributes not worth showing in a change diff (always-present, low-signal).
  IGNORED_CHANGE_KEYS = %w[updated_at created_at].freeze

  # The meaningful field-level changes for a version, as { attr => [old, new] },
  # with noise (timestamps) stripped. Returns {} when nothing survives.
  def change_control_diff(version)
    (version.changeset || {}).except(*IGNORED_CHANGE_KEYS)
  end

  # Render one side of a diff for display: nil as an em-dash, arrays joined,
  # everything else as a plain string.
  def change_control_value(value)
    return content_tag(:span, "∅", class: "text-muted") if value.nil?
    return content_tag(:span, "(vacío)", class: "text-muted") if value.respond_to?(:empty?) && value.empty?

    display = value.is_a?(Array) ? value.join(", ") : value.to_s
    truncate(display, length: 120)
  end

  # Bootstrap badge colour for a PaperTrail event.
  def change_control_event_badge(event)
    { "create" => "success", "update" => "primary", "destroy" => "danger" }.fetch(event, "secondary")
  end

  # Human name for the acting user behind a version's whodunnit, using a
  # preloaded { id_string => User } map.
  def change_control_editor_name(version, editors)
    if (editor = editors[version.whodunnit])
      editor.fullname.presence || editor.email
    elsif version.whodunnit.present?
      content_tag(:span, "Usuario ##{version.whodunnit} (eliminado)", class: "text-muted")
    else
      content_tag(:span, "Sistema / sin sesión", class: "text-muted")
    end
  end
end
