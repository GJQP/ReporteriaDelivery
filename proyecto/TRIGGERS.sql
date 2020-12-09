--SIMULACION

--MANTENIMIENTO
CREATE OR REPLACE TRIGGER registro_mantenimiento_unidades
BEFORE UPDATE OF estado ON unidades_de_transporte
FOR EACH ROW
WHEN ( NEW.estado = 'REPARACION' )
BEGIN
INSERT INTO registro_de_mantenimiento(id_app,id_garaje,id_unidad,id,fecha_registro)
VALUES (:OLD.id_app,:OLD.id_garaje,:OLD.id,DEFAULT,SYSDATE);
END;