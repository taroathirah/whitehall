# @abstract
class Classification < ActiveRecord::Base
  include Searchable
  include SimpleWorkflow

  searchable title: :name,
             link: :search_link,
             content: :description,
             description: :description_without_markup,
             format: 'topic',
             slug: :slug

  has_many :classification_memberships, inverse_of: :classification
  has_many :editions, through: :classification_memberships

  has_many :organisation_classifications
  has_many :organisations, through: :organisation_classifications
  has_many :classification_relations, inverse_of: :classification
  has_many :related_classifications,
            through: :classification_relations,
            before_remove: -> pa, rpa {
              ClassificationRelation.relation_for(pa.id, rpa.id).destroy_inverse_relation
            }

  has_many :classification_featurings,
            -> { where("editions.state = 'published' or classification_featurings.edition_id is null").
                 references(:edition).
                 includes(edition: :translations).
                 order("classification_featurings.ordering asc") },
            foreign_key: :classification_id,
            inverse_of: :classification

  has_many :featured_editions,
            -> { order("classification_featurings.ordering ASC") },
            through: :classification_featurings,
            source: :edition

  has_many :classification_policies

  validates_with SafeHtmlValidator
  validates_with NoFootnotesInGovspeakValidator, attribute: :description

  validates :name, presence: true, uniqueness: true
  validates :description, presence: true

  accepts_nested_attributes_for :classification_memberships
  accepts_nested_attributes_for :organisation_classifications
  accepts_nested_attributes_for :classification_featurings

  has_many :offsite_links, as: :parent

  scope :alphabetical, -> { order("name ASC") }

  mount_uploader :logo, ImageUploader, mount_on: :carrierwave_image

  extend FriendlyId
  friendly_id

  def self.grouped_by_type
    Rails.cache.fetch("filter_options/topics", expires_in: 30.minutes) do
      {
        'Topics' => Topic.alphabetical.map { |o| [o.name, o.slug] },
        'Topical events' => TopicalEvent.active.order_by_start_date.map { |o| [o.name, o.slug] }
      }
    end
  end

  def published_editions
    editions.published
  end

  def scheduled_editions
    editions.scheduled.order('scheduled_publication ASC')
  end

  def published_announcements
    published_editions.announcements
  end

  def published_consultations
    published_editions.consultations
  end

  def published_detailed_guides
    published_editions.detailed_guides
  end

  def published_non_statistics_publications
    published_editions.non_statistical_publications
  end

  def published_statistics_publications
    published_editions.statistical_publications
  end

  def lead_organisations
    organisations.where(organisation_classifications: {lead: true}).reorder("organisation_classifications.lead_ordering")
  end

  def lead_organisation_classifications
    organisation_classifications.where(lead: true).order("organisation_classifications.lead_ordering")
  end

  def importance_ordered_organisations
    organisations.reorder("organisation_classifications.lead DESC, organisation_classifications.lead_ordering")
  end

  def destroyable?
    policies.empty?
  end

  def search_link
    Whitehall.url_maker.topic_path(slug)
  end

  def latest(limit = 3)
    published_editions.without_editions_of_type(WorldLocationNewsArticle).in_reverse_chronological_order.includes(:translations).limit(limit)
  end

  def description_without_markup
    Govspeak::Document.new(description).to_text
  end

  def featured?(edition)
    return false unless edition.persisted?
    featuring_of(edition).present?
  end

  def featuring_of(edition)
    classification_featurings.detect { |cf| cf.edition == edition }
  end

  def feature(featuring_params)
    classification_featurings.create({ordering: next_ordering}.merge(featuring_params))
  end

  def next_ordering
    last = classification_featurings.order("ordering desc").limit(1).last
    last ? last.ordering + 1 : 1
  end

  def to_s
    name
  end

  def policy_content_ids
    classification_policies.map(&:policy_content_id)
  end

  def policy_content_ids=(content_ids)
    self.classification_policies = content_ids.map do |content_id|
      ClassificationPolicy.new(policy_content_id: content_id)
    end
  end

  def policies
    Future::Policy.from_content_ids(policy_content_ids)
  end

private
  def logo_changed?
    changes["carrierwave_image"].present?
  end
end
