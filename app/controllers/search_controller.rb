# Global navbar search. The heavy lifting (permission + branch scoping per
# record type) lives in GlobalSearch, so this controller just runs the query
# and hands grouped results to the view.
class SearchController < SecureApplicationController
  # GlobalSearch enforces authorization itself, per record type, via each role's
  # can_show flag and branch scope — there is no single resource to `authorize`
  # here, so opt out of the deny-by-default check rather than fake one.
  skip_after_action :verify_authorized

  def index
    @query = params[:q].to_s.strip
    @groups = @query.present? ? GlobalSearch.new(user: current_user, query: @query).call : []
  end
end
