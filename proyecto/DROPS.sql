-- REPORTES
DROP PROCEDURE REPORTE1;
DROP PROCEDURE REPORTE2;
DROP PROCEDURE REPORTE3;
DROP PROCEDURE REPORTE4;
DROP PROCEDURE REPORTE5;
DROP PROCEDURE REPORTE6;
/
-- TRIGGERS

DROP TRIGGER se_ha_eliminado_una_ruta;
DROP TRIGGER se_ha_creado_una_ruta;
DROP TRIGGER se_ha_cancelado_un_pedido;
DROP TRIGGER se_ha_hecho_un_nuevo_pedido;
DROP TRIGGER se_ha_cambiado_el_estado_de_la_unidad;
DROP TRIGGER se_inserta_una_nueva_unidad;
DROP TRIGGER se_ha_creado_una_promocion;
DROP TRIGGER se_ha_cancelado_un_contrato;
DROP TRIGGER registro_mantenimiento_unidades;
/
-- PROCEDURES
DROP PROCEDURE insertar_app_delivery;
DROP PROCEDURE insertar_empresa;
DROP PROCEDURE insertar_usuario;
/
--SIMULACION
DROP PROCEDURE update_sim_time;
DROP FUNCTION sim_date;

--contratos
DROP PROCEDURE modulo_contratos;
DROP PROCEDURE crear_plan_servicio;
DROP PROCEDURE crear_contrato;
DROP FUNCTION obtener_empresa_no_contratada;

--mantenimiento
DROP PROCEDURE MODULO_MANTENIMIENTO;

--pedidos
DROP FUNCTION SUCURSAL_FACTIBLE;
DROP PROCEDURE CREAR_PEDIDO_ALEATORIO;
DROP FUNCTION OBTENER_DESCUENTOS;
DROP FUNCTION OBTENER_USUARIO_AZAR_PEDIDO;
DROP PROCEDURE MODULO_PEDIDO;

--despachos
DROP PROCEDURE modulo_despacho;
DROP FUNCTION CREAR_UBICACION;
DROP PROCEDURE simular_accidente;
DROP FUNCTION UNIDAD_DISPONIBLE;
/
-- TABLES
DROP TABLE sim_time;
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


