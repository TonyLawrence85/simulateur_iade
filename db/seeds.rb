# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# db/seeds.rb

puts "🌱 Seeding valeur du point d'indice…"

PointValue.find_or_create_by!(date_debut: Date.new(2023, 7, 1)) do |pv|
  pv.valeur           = 4.92284
  pv.reference_decret = "Décret 2023-519 du 28/06/2023"
end

puts "🌱 Seeding grille indiciaire IADE — Grade 1…"

grille_grade1 = {
  1 => 340, 2 => 358, 3 => 379, 4 => 405, 5 => 430,
  6 => 458, 7 => 487, 8 => 514, 9 => 541, 10 => 566, 11 => 583
}

grille_grade1.each do |echelon, im|
  GradeScale.find_or_create_by!(grade: "grade1", echelon: echelon, date_debut: Date.new(2023, 7, 1)) do |gs|
    gs.indice_majore = im
    gs.source         = "PPCR 2023"
  end
end

puts "🌱 Seeding grille indiciaire IADE — Grade 2…"

grille_grade2 = {
  1 => 517, 2 => 536, 3 => 556, 4 => 577, 5 => 598,
  6 => 618, 7 => 638, 8 => 659, 9 => 680, 10 => 700, 11 => 718
}

grille_grade2.each do |echelon, im|
  GradeScale.find_or_create_by!(grade: "grade2", echelon: echelon, date_debut: Date.new(2023, 7, 1)) do |gs|
    gs.indice_majore = im
    gs.source         = "PPCR 2023"
  end
end

puts "🌱 Seeding zones d'indemnité de résidence (Île-de-France)…"

zones = {
  "75" => [1, "Paris"],
  "92" => [1, "Hauts-de-Seine"],
  "93" => [1, "Seine-Saint-Denis"],
  "94" => [1, "Val-de-Marne"],
  "77" => [2, "Seine-et-Marne"],
  "78" => [2, "Yvelines"],
  "91" => [2, "Essonne"],
  "95" => [2, "Val-d'Oise"]
}

zones.each do |code, (zone, nom)|
  DepartmentZone.find_or_create_by!(code: code, date_debut: Date.new(1967, 3, 28)) do |dz|
    dz.nom  = nom
    dz.zone = zone
  end
end

puts "✅ Seed terminé !"
puts "   #{PointValue.count} valeur(s) de point"
puts "   #{GradeScale.count} échelons de grille indiciaire"
puts "   #{DepartmentZone.count} zones de résidence"
