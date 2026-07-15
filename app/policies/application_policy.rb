# frozen_string_literal: true

# Generic, permission-driven base policy. Every action maps to a per-resource
# permission on the current user's Role:
#   index/show   -> can_show
#   new/create   -> can_edit
#   edit/update  -> can_edit
#   destroy      -> can_delete
# Per-model policies inherit this for free; they only override to add bespoke
# rules (e.g. PatientPolicy's AASM state transitions).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    permitted?(:can_show)
  end

  def show?
    permitted?(:can_show)
  end

  def create?
    permitted?(:can_edit)
  end

  def new?
    create?
  end

  def update?
    permitted?(:can_edit)
  end

  def edit?
    update?
  end

  def destroy?
    permitted?(:can_delete)
  end

  private

  def permitted?(action)
    return false if user&.role.nil?

    user.role.permits?(record_class, action)
  end

  # `record` is a Class for collection/new actions (authorize(Model)) and an
  # instance for member actions (authorize(@instance)).
  def record_class
    record.is_a?(Class) ? record : record.class
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user&.role&.permits?(model_class, :can_show)
        scope.all
      else
        scope.none
      end
    end

    private

    # `scope` is the model CLASS when called as `policy_scope(Patient)` (the
    # common Pundit form) and a RELATION when called as `policy_scope(Patient.all)`.
    # Only the relation responds to `klass`, so asking for it unconditionally blew
    # up on the class form — latent until the first policy_scope call site existed.
    def model_class
      scope.respond_to?(:klass) ? scope.klass : scope
    end

    attr_reader :user, :scope
  end
end
