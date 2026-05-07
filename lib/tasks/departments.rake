namespace :departments do
  desc "Merge duplicate/aliased departments into their canonical names"
  task merge_duplicates: :environment do
    merges = {}

    Department.all.each do |dept|
      resolved = Department::ALIASES[dept.name.downcase.strip]
      if resolved
        canonical_dept = Department.find_by("LOWER(name) = ?", resolved.downcase)
        merges[dept] = canonical_dept if canonical_dept && canonical_dept.id != dept.id
      end
    end

    all_depts = Department.all.to_a
    all_depts.each do |dept|
      next if merges.key?(dept)
      others = all_depts.reject { |d| d.id == dept.id || merges.key?(d) }
      closest = others.min_by { |d| Department.levenshtein(d.name.downcase, dept.name.downcase) }
      next unless closest
      distance = Department.levenshtein(closest.name.downcase, dept.name.downcase)
      next unless distance <= 2 && distance.positive?
      keep, drop = [dept, closest].minmax_by(&:name)
      merges[drop] = keep unless merges.key?(drop)
    end

    if merges.empty?
      puts "No duplicates found."
      next
    end

    puts "\nPlanned merges:"
    merges.each { |drop, keep| puts "  \"#{drop.name}\" → \"#{keep.name}\"" }
    print "\nProceed? (y/n): "
    next unless $stdin.gets.chomp.downcase == "y"

    merges.each do |drop, keep|
      ActiveRecord::Base.transaction do
        Dataset.where(department_id: drop.id).update_all(department_id: keep.id)
        drop.department_profile&.destroy
        drop.ai_summary&.destroy
        drop.destroy!
      end
      puts "  #{drop.name} → #{keep.name}"
    end

    puts "\nRefreshing profiles..."
    merges.values.uniq.each do |dept|
      DepartmentProfileService.refresh(dept)
      puts "  #{dept.name}"
    end
  end
end
