class DatasetColumn < ApplicationRecord
  belongs_to :dataset, inverse_of: :dataset_columns

  enum :data_type, {
    numeric: 0,
    categorical: 1,
    date: 2,
    text: 3
  }, prefix: :type

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
