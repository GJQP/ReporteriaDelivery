-- REPORTES
DROP PROCEDURE REPORTE1;
DROP PROCEDURE REPORTE2;
DROP PROCEDURE REPORTE3;
DROP PROCEDURE REPORTE4;
DROP PROCEDURE REPORTE5;
DROP PROCEDURE REPORTE6;
/
-- TRIGGERS
DROP TRIGGER registro_mantenimiento_unidades;
/
-- PROCEDURES
DROP PROCEDURE insertar_app_delivery;
DROP PROCEDURE insertar_empresa;
DROP PROCEDURE insertar_usuario;
/
--SIMULACION

--contratos
DROP PROCEDURE modulo_contratos;
DROP PROCEDURE crear_plan_servicio;
DROP PROCEDURE crear_contrato;
DROP FUNCTION obtener_empresa_no_contratada;

--mantenimiento
DROP PROCEDURE MODULO_MANTENIMIENTO;
/
-- TABLES
DROP TABLE rutas;
DROP TABLE detalles;
DROP TABlE pedidos;
DROP TABLE direcciones;
DROP TABLE registros;
DROP TABLE usuarios;
DROP TABLE almacenes;
DROP TABLE productos;
DROP TABLE eventos;
DROP TABLE sucursales;
DROP TABLE contratos;
DROP TABLE ubicaciones_aplicables;
DROP TABLE planes_de_servicio;
DROP TABLE empresas;
DROP TABLE sectores_de_comercio;
DROP TABLE registro_de_mantenimiento;
DROP TABLE unidades_de_transporte;
DROP TABLE tipos_de_unidades;
DROP TABLE garajes;
DROP TABLE aplicaciones_delivery;
DROP TABLE zonas;
DROP TABLE municipios;
DROP TABLE estados;
/
--TYPES
DROP TYPE UBICACION;
DROP TYPE CANCELACION;
DROP TYPE MARCA;
DROP TYPE RANGO_TIEMPO;
/