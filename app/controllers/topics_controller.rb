class TopicsController < ApplicationController
  def index
    @topics = Topic.with_published_documents
  end

  def show
    @topic = Topic.find(params[:id])
    @policies = Policy.published.in_topic(@topic).order("document_topics.ordering ASC")
    @news_articles = NewsArticle.published.in_topic(@topic)
  end
end