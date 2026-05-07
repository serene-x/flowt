class DataRow < ApplicationRecord
  belongs_to :dataset, inverse_of: :data_rows

  validates :row_index, presence: true
end
