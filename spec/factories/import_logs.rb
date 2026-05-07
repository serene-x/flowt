FactoryBot.define do
  factory :import_log do
    dataset { nil }
    summary { "" }
    warnings { "" }
    cleaning_diff { "" }
  end
end
