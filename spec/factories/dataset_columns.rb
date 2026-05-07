FactoryBot.define do
  factory :dataset_column do
    dataset { nil }
    name { "MyString" }
    position { 1 }
    data_type { 1 }
    stats { "" }
  end
end
