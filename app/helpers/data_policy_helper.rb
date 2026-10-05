# Rendering helpers for the política de tratamiento de datos (DataPolicy).
module DataPolicyHelper
  # The policy text carries **bold** for the phrases a reader must not miss —
  # the facultative nature of sensitive data, the legal deadlines, "no vendemos
  # sus datos". Everything is escaped first, so the only markup that survives is
  # the emphasis this method puts back.
  def policy_text(text)
    escaped = ERB::Util.html_escape(text).to_str
    escaped.gsub(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }.html_safe
  end

  # A value the deployment has not filled in yet renders marked rather than
  # blank, so an incomplete policy is obvious on the page instead of quietly
  # naming nobody.
  def policy_value(value)
    return value unless DataPolicy.pending?(value)

    tag.span(value, class: "policy-pending")
  end
end
