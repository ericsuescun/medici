# robots.txt and sitemap.xml — what Google reads to decide what to index.
#
# Served from a controller rather than public/ so both carry the real host,
# whatever it is: the Heroku default today, a custom domain tomorrow, a review
# app in between. A hardcoded absolute Sitemap: line in a static robots.txt is
# wrong the moment the domain changes, and silently so.
#
# public/robots.txt was deleted for this to be reachable — the static file server
# answers before the router, so a file of that name would shadow this action.
class SitemapsController < ApplicationController
  def robots
    render layout: false, content_type: "text/plain"
  end

  def sitemap
    # Every study has a public "more about this study" page (StaticPages#study_details);
    # that is the page worth indexing, and the one a social post links to.
    @studies = Study.order(:id)
    @cities = City.order(:name)
    render layout: false, content_type: "application/xml"
  end
end
