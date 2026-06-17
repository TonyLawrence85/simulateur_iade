# db/seeds.rb
# Données de référence — idempotentes avec mise à jour si nécessaire

puts "🌱 Seeding valeur du point d'indice…"

pv = PointValue.find_or_initialize_by(date_debut: Date.new(2023, 7, 1))
pv.valeur           = 4.92278
pv.reference_decret = "Décret 2023-519 du 28/06/2023 — valeur au 01/01/2024 : 4,92278 €/point"
pv.save!

puts "🌱 Seeding grille indiciaire IADE — Grade 1 (10 échelons)…"

# Source : emploi-collectivites.fr — vérifié le 18/04/2026
grille_grade1 = {
  1 => 450, 2 => 478, 3 => 506, 4 => 534, 5 => 563,
  6 => 593, 7 => 624, 8 => 656, 9 => 690, 10 => 727
}

grille_grade1.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "grade1", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "PPCR — grille vérifiée 18/04/2026"
  gs.save!
end

# Supprimer l'ancien échelon 11 du grade 1 (inexistant dans la grille officielle)
GradeScale.where(grade: "grade1", echelon: 11).destroy_all

puts "🌱 Seeding grille indiciaire IADE — Grade 2 (8 échelons)…"

grille_grade2 = {
  1 => 558, 2 => 582, 3 => 615, 4 => 648,
  5 => 681, 6 => 714, 7 => 743, 8 => 769
}

grille_grade2.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "grade2", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "PPCR — grille vérifiée 18/04/2026"
  gs.save!
end

# Supprimer les anciens échelons 9-11 du grade 2 (inexistants dans la grille officielle)
GradeScale.where(grade: "grade2", echelon: 9..11).destroy_all

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
  dz = DepartmentZone.find_or_initialize_by(code: code, date_debut: Date.new(1967, 3, 28))
  dz.nom  = nom
  dz.zone = zone
  dz.save!
end

puts "✅ Seed terminé !"
puts "   #{PointValue.count} valeur(s) de point"
puts "   #{GradeScale.count} échelons de grille indiciaire"
puts "   #{DepartmentZone.count} zones de résidence"
