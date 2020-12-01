/*
CREATE OR REPLACE VIEW ubicaciones(id_zona,zona,municipio,estado,id_municipio,id_estado) AS
SELECT z.id_estado,z.id_municipio,z.id, z.nombre, m.nombre, e.nombre FROM estados e
JOIN municipios m ON e.id = m.id_estado
JOIN zonas z ON m.id_estado = z.id_estado AND m.id = z.id_municipio
ORDER BY id_estado
*/
