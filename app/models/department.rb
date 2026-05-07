class Department < ApplicationRecord
  has_many :datasets, dependent: :nullify
  has_one :department_profile, dependent: :destroy
  has_one :ai_summary, dependent: :destroy

  def relevant_datasets
    direct = Dataset.where(department_id: id)
    by_row_ids = Dataset.where(id: DataRow.where("data->>'department' = ?", name).select(:dataset_id))
    Dataset.where(id: direct.select(:id)).or(Dataset.where(id: by_row_ids.select(:id))).distinct
  end

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug

  ALIASES = {
    "mktg"              => "Marketing",
    "mkt"               => "Marketing",
    "eng"               => "Engineering",
    "enginering"        => "Engineering",
    "engingeering"      => "Engineering",
    "people operations" => "People Ops",
    "people op"         => "People Ops",
    "peopleops"         => "People Ops",
    "hr"                => "People Ops",
    "human resources"   => "People Ops",
    "sls"               => "Sales",
  }.freeze

  def self.normalize_name(value)
    stripped = value.to_s.strip.gsub(/\s+/, " ")
    return "" if stripped.blank?

    key = stripped.downcase
    return ALIASES[key] if ALIASES.key?(key)

    stripped.split(/\s+/).map(&:capitalize).join(" ")
  end

  def self.find_or_create_by_name(value)
    name = normalize_name(value)
    return nil if name.blank?

    existing = find_by("LOWER(name) = ?", name.downcase)
    return existing if existing

    fuzzy = fuzzy_match(name)
    return fuzzy if fuzzy

    create!(name: name)
  end

  def self.fuzzy_match(name, max_distance: 2)
    all.min_by { |d| levenshtein(d.name.downcase, name.downcase) }
       .then { |d| d if d && levenshtein(d.name.downcase, name.downcase) <= max_distance }
  end

  def self.levenshtein(a, b)
    return b.length if a.empty?
    return a.length if b.empty?

    matrix = Array.new(a.length + 1) { |i| Array.new(b.length + 1) { |j| i.zero? ? j : j.zero? ? i : 0 } }
    (1..a.length).each do |i|
      (1..b.length).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        matrix[i][j] = [matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost].min
      end
    end
    matrix[a.length][b.length]
  end

  def to_param
    slug
  end

  private

  def assign_slug
    return if slug.present?
    return if name.blank?

    base = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
    candidate = base
    counter = 2
    while Department.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end
    self.slug = candidate
  end
end
