require "csv"

class ChangeControlsController < SecureApplicationController
  # Whitelist of audited models exposed through the change-control view, keyed by
  # the param value so an arbitrary class name can never be constantized from input.
  TRACKED_MODELS = {
    "Patient" => Patient,
    "Study" => Study,
    "CriteriaProfile" => CriteriaProfile,
    "CriteriaVariable" => CriteriaVariable,
    "VariableValue" => VariableValue
  }.freeze

  def show
    @item = find_item
    authorize @item, :show?, policy_class: ChangeControlPolicy

    # Editors are drawn from ALL versions (not the filtered set) so the user filter
    # always lists everyone who ever touched the record.
    @editors = editors_for(@item)
    @versions = filtered_versions

    respond_to do |format|
      format.html
      format.csv do
        send_data change_control_csv(@versions, @editors),
                  filename: "change-control-#{params[:item_type].underscore}-#{@item.id}.csv"
      end
    end
  end

  private

  def find_item
    klass = TRACKED_MODELS[params[:item_type]]
    raise ActiveRecord::RecordNotFound, "Untracked type" unless klass

    klass.find(params[:item_id])
  end

  # Apply the optional filters: event type, acting user (whodunnit), and date range.
  def filtered_versions
    scope = @item.versions.reorder(created_at: :desc, id: :desc)
    scope = scope.where(event: params[:event]) if params[:event].present?
    scope = scope.where(whodunnit: params[:whodunnit]) if params[:whodunnit].present?
    if (from = parse_date(params[:from]))
      scope = scope.where(created_at: from.beginning_of_day..)
    end
    if (to = parse_date(params[:to]))
      scope = scope.where(created_at: ..to.end_of_day)
    end
    scope
  end

  def editors_for(item)
    ids = item.versions.reorder(nil).distinct.pluck(:whodunnit).compact
    User.where(id: ids).index_by { |u| u.id.to_s }
  end

  def parse_date(str)
    return nil if str.blank?

    Date.parse(str)
  rescue ArgumentError
    nil
  end

  def change_control_csv(versions, editors)
    CSV.generate(headers: true) do |csv|
      csv << %w[fecha evento usuario campo antes despues]
      versions.each do |version|
        editor = editors[version.whodunnit]
        who = editor ? (editor.fullname.presence || editor.email) : version.whodunnit
        changes = helpers.change_control_diff(version)
        if changes.empty?
          csv << [ version.created_at, version.event, who, nil, nil, nil ]
        else
          changes.each do |attr, (old_val, new_val)|
            csv << [ version.created_at, version.event, who, attr, old_val, new_val ]
          end
        end
      end
    end
  end
end
