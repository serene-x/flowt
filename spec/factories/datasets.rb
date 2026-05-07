FactoryBot.define do
  factory :dataset do
    name { "MyString" }
    dataset_type { 1 }
    department { nil }
    original_filename { "MyString" }
    row_count { 1 }
    skipped_count { 1 }
    status { 1 }
    imported_at { "2026-05-07 11:26:29" }
  end
end
