--- Lecturas permitidas
SELECT * FROM APLICACIONES_DELIVERY;
SELECT * FROM EMPRESAS;
SELECT * FROM SUCURSALES;
SELECT * FROM ALMACENES;
SELECT * FROM EVENTOS;
SELECT * FROM PRODUCTOS;
SELECT * FROM PEDIDOS;
SELECT * FROM DETALLES;
SELECT * FROM RUTAS;
SELECT * FROM UNIDADES_DE_TRANSPORTE;
SELECT * FROM TIPOS_DE_UNIDADES;
SELECT * FROM REGISTROS;
SELECT * FROM USUARIOS;
SELECT * FROM DIRECCIONES;
SELECT * FROM ZONAS;
SELECT * FROM MUNICIPIOS;
SELECT * FROM ESTADOS;

-- Lecturas no permitidas
SELECT * FROM PLANES_DE_SERVICIO;
SELECT * FROM UBICACIONES_APLICABLES;
SELECT * FROM CONTRATOS;
SELECT * FROM GARAJES;
SELECT * FROM REGISTRO_DE_MANTENIMIENTO;


---- CREATES permitidos

-- crear pedidos y detalles
INSERT INTO pedidos VALUES (1,1,2,10,DEFAULT,24,335,1120,9,24,RANGO_TIEMPO(TO_DATE('11/12/2020', 'dd/mm/yyyy'),TO_DATE('11/12/2020', 'dd/mm/yyyy')),32.22,NULL,4,NULL);
INSERT INTO detalles VALUES (2,29,11,1,DEFAULT,1.74, 3);
INSERT INTO detalles VALUES (2,29,14,1,DEFAULT,2.00, 3);
INSERT INTO detalles VALUES (2,29,19,1,DEFAULT,7.00, 3);



---- CREATES no permitidos
-- crear producto
INSERT INTO PRODUCTOS VALUES (1, 1, DEFAULT, 'Pepsicola 2Lts', 1.7, 0, 'Botella de Pepsicola tradicional de 2Lts');

-- crear una sucursal
INSERT INTO  sucursales VALUES (24,335,1117,1,DEFAULT,UBICACION(10.509909,-66.913139,SYSDATE));

---- UPDATES permitidos

-- cambiar nombre de usuario
UPDATE usuarios SET primer_nombre = 'Juan' WHERE ID = 1;
-- cambiar direccion
UPDATE DIRECCIONES SET DESCRIPCION = 'Calle Av. Victoria' WHERE ID = 1;

---- UPDATES no permitidos

-- cambiar precio de producto
UPDATE PRODUCTOS SET precio = 0 WHERE ID = 2;

-- cambiar precio de detalle pedido
UPDATE DETALLES SET PRECIO_UNITARIO=2 WHERE ID = 2;

---- DELETES permitidos
DELETE FROM DIRECCIONES WHERE ID = 2;

---- DELETES no permitidos

-- borrar un pedido
DELETE FROM pedidos WHERE ID = 2;

-- borrar un usuario
DELETE FROM usuarios WHERE ID = 4;
