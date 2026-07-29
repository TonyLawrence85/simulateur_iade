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

puts "🌱 Seeding grille indiciaire AS — Classe normale (11 échelons)…"

grille_as_grade1 = {
  1 => 373, 2 => 375, 3 => 377, 4 => 388, 5 => 401,
  6 => 414, 7 => 429, 8 => 444, 9 => 461, 10 => 485, 11 => 517
}
grille_as_grade1.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "as_grade1", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "emploi-collectivites.fr — vérifié le 19/05/2026"
  gs.save!
end

puts "🌱 Seeding grille indiciaire AS — Classe supérieure (11 échelons)…"

grille_as_grade2 = {
  1 => 387, 2 => 399, 3 => 411, 4 => 424, 5 => 442,
  6 => 460, 7 => 480, 8 => 499, 9 => 519, 10 => 539, 11 => 560
}
grille_as_grade2.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "as_grade2", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "emploi-collectivites.fr — vérifié le 19/05/2026"
  gs.save!
end

puts "🌱 Seeding grille indiciaire IDE — Grade normal (10 échelons)…"

grille_ide_grade1 = {
  1 => 376, 2 => 394, 3 => 413, 4 => 439, 5 => 466,
  6 => 496, 7 => 527, 8 => 553, 9 => 578, 10 => 610
}
grille_ide_grade1.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "ide_grade1", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "FPH PPCR 2024 — grille Infirmier en soins généraux"
  gs.save!
end

puts "🌱 Seeding grille indiciaire IDE — Classe supérieure (8 échelons)…"

grille_ide_grade2 = {
  1 => 446, 2 => 463, 3 => 487, 4 => 514,
  5 => 543, 6 => 572, 7 => 601, 8 => 626
}
grille_ide_grade2.each do |echelon, im|
  gs = GradeScale.find_or_initialize_by(grade: "ide_grade2", echelon: echelon, date_debut: Date.new(2023, 7, 1))
  gs.indice_majore = im
  gs.source        = "FPH PPCR 2024 — grille Infirmier classe supérieure"
  gs.save!
end

puts "✅ Seed terminé !"
puts "   #{PointValue.count} valeur(s) de point"
puts "   #{GradeScale.count} échelons de grille indiciaire"
puts "   #{DepartmentZone.count} zones de résidence"
