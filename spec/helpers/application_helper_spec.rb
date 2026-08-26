require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#transition_hint_args" do
    it "names the button, the state the patient is in, and the one the step lands in" do
      expect(helper.transition_hint_args(Patient.new(state: "candidate"))).to eq(
        state: I18n.t("patients.states.candidate"),
        event: I18n.t("patients.accept"),
        from: I18n.t("patients.states.candidate"),
        to: I18n.t("patients.states.participant"),
        back_event: I18n.t("patients.discard"),
        back_to: I18n.t("patients.states.interested")
      )
    end

    it "carries the score when one is given" do
      expect(helper.transition_hint_args(Patient.new(state: "interested"), score: 80)).to include(score: 80)
    end

    it "drops a nil score rather than passing it through" do
      expect(helper.transition_hint_args(Patient.new(state: "interested"), score: nil)).not_to have_key(:score)
    end

    it "offers no backward step at the start of the lifecycle" do
      args = helper.transition_hint_args(Patient.new(state: "interested"))

      expect(args).to include(event: I18n.t("patients.assess"), to: I18n.t("patients.states.candidate"))
      expect(args).not_to have_key(:back_event)
    end

    # The end of the line still needs args: the take-action box has to be able to
    # say "«Rechazar» lo devuelve a Candidato" instead of falling through to
    # promotion advice for a step that does not exist.
    it "still names the backward step at the end of the lifecycle, where there is nothing to promote to" do
      args = helper.transition_hint_args(Patient.new(state: "participant"))

      expect(args).to eq(
        state: I18n.t("patients.states.participant"),
        back_event: I18n.t("patients.reject"),
        back_to: I18n.t("patients.states.candidate")
      )
      expect(args).not_to have_key(:event)
    end
  end

  # The take-action hints tell a rep what pressing the button will DO — "«Aceptar»
  # promueve al paciente de Candidato a Participante" — so every one of them has
  # to render in every language. A locale that references an interpolation the
  # helper does not supply raises at render time, in front of the rep; one that
  # forgot %{from}/%{to} silently goes back to the vague old copy.
  describe "the take-action hints, in every language" do
    FORWARD_HINT_KEYS = %w[
      criteria_assessments.locked.hint
      criteria_assessments.brief.promote_hint_eligible
      criteria_assessments.score.promote_hint_ready
      criteria_assessments.score.promote_hint_promising
      criteria_assessments.score.promote_hint_blocked
      criteria_assessments.score.promote_hint_pending
    ].freeze

    I18n.available_locales.each do |locale|
      context "in #{locale}" do
        # A candidate, so the step under discussion is candidate -> participant.
        let(:args) { helper.transition_hint_args(Patient.new(state: "candidate"), score: 80) }

        it "renders every hint without a missing interpolation" do
          I18n.with_locale(locale) do
            FORWARD_HINT_KEYS.each do |key|
              expect { I18n.t!(key, **args) }.not_to raise_error, "#{key} does not render in #{locale}"
            end
          end
        end

        it "names both ends of the step in every hint" do
          I18n.with_locale(locale) do
            from = I18n.t("patients.states.candidate")
            to = I18n.t("patients.states.participant")

            FORWARD_HINT_KEYS.each do |key|
              rendered = I18n.t!(key, **args)

              expect(rendered).to include(from), "#{key} in #{locale} does not say which state the patient is in"
              expect(rendered).to include(to), "#{key} in #{locale} does not say which state the step lands in"
            end
          end
        end

        it "names the state and the way back in the end-of-lifecycle hint" do
          I18n.with_locale(locale) do
            rendered = I18n.t!("criteria_assessments.brief.at_final_state",
                               **helper.transition_hint_args(Patient.new(state: "participant")))

            expect(rendered).to include(I18n.t("patients.states.participant"))
            expect(rendered).to include(I18n.t("patients.reject"))
            expect(rendered).to include(I18n.t("patients.states.candidate"))
          end
        end
      end
    end
  end
end
