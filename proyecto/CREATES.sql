-- CREATES TABLES
CREATE OR REPLACE TYPE MARCA AS OBJECT(
    nombre VARCHAR2(80),
    rif VARCHAR2(18),
    fecha_de_registro DATE,
    CONSTRUCTOR FUNCTION MARCA(SELF IN OUT NOCOPY MARCA, nombre VARCHAR2, RIF VARCHAR2, fecha_de_registro DATE) RETURN SELF AS RESULT,
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY MARCA IS
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF REGEXP_LIKE(rif, '^J[[:digit:]]{8}-[[:digit:]]') THEN
            RETURN rif;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: El rif no es válido');
        END IF;
    END;

    CONSTRUCTOR FUNCTION MARCA(SELF IN OUT NOCOPY MARCA, nombre VARCHAR2, rif VARCHAR2, fecha_de_registro DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.nombre := nombre;
        SELF.rif := MARCA.VALIDAR_RIF(rif);
        SELF.fecha_de_registro := fecha_de_registro;
        RETURN;
    END;
END;
/
CREATE OR REPLACE TYPE RANGO_TIEMPO AS OBJECT (
    fecha_inicio DATE,
    fecha_fin DATE,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT,
    STATIC FUNCTION VALIDO(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION VENCIDO(fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2,
    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY RANGO_TIEMPO IS
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := NULL;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo,fecha_inicio DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := fecha_inicio;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT IS
    BEGIN
        IF RANGO_TIEMPO.valido(fecha_inicio,fecha_fin) THEN
            SELF.fecha_inicio := fecha_inicio;
            SELF.fecha_fin := fecha_fin;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos');
        END IF;
        RETURN;
    END;

    STATIC FUNCTION VALIDO(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN fecha_inicio <= fecha_fin;
    END;

    STATIC FUNCTION VENCIDO(fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN SYSDATE > fecha_fin;
    END;

   STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2
    AS
        d_diff NUMBER;
    BEGIN
        d_diff := fecha_fin - fecha_objetivo;
        IF (NOT RANGO_TIEMPO.valido(fecha_objetivo,fecha_fin)) THEN RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos'); END IF;

        IF (d_diff < 1) THEN
            RETURN REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSIF (d_diff < 2) THEN
            RETURN TRUNC(d_diff) || ' dia ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSE
            RETURN TRUNC(d_diff) || ' dias ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        END IF;

    END;

    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TIEMPO_PARA_CADUCAR(fecha_fin,CURRENT_DATE);
    END;
END;
/
CREATE OR REPLACE TYPE CANCELACION AS OBJECT (
   fecha_cancelacion DATE,
   motivo VARCHAR(2000),
   CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT,
   CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT,
   STATIC FUNCTION VALIDAR_FINALIZACION(fecha_cancelacion DATE) RETURN DATE
);
/
CREATE OR REPLACE TYPE BODY CANCELACION IS
    CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_cancelacion := CANCELACION.VALIDAR_FINALIZACION(fecha_cancelacion);
        SELF.motivo := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_cancelacion := CANCELACION.VALIDAR_FINALIZACION(fecha_cancelacion);
        SELF.motivo := motivo;
        RETURN;
    END;

    STATIC FUNCTION VALIDAR_FINALIZACION(fecha_cancelacion DATE) RETURN DATE IS
    BEGIN
        IF fecha_cancelacion > SYSDATE THEN
            RETURN fecha_cancelacion;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: la fecha de caducidad no puede ser menor a la actual');
        END IF;
    END;
END;
/
CREATE OR REPLACE TYPE UBICACION AS OBJECT (
    coordenada SDO_GEOMETRY,
    actualizado TIMESTAMP,
    MEMBER FUNCTION OBTENER_POSICION(timpo_transcurrido TIMESTAMP, velocidad_med NUMBER) RETURN SDO_GEOMETRY
);
/
CREATE OR REPLACE TYPE BODY UBICACION IS
    MEMBER FUNCTION OBTENER_POSICION(timpo_transcurrido TIMESTAMP, velocidad_med NUMBER) RETURN SDO_GEOMETRY IS
    BEGIN
        RETURN NULL;
    END;
END;
/
CREATE TABLE estados(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
);
/
CREATE TABLE municipios(
    id_estado INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(80) NOT NULL,
    FOREIGN KEY(id_estado) REFERENCES estados(id),
    PRIMARY KEY(id_estado, id)
);
/
CREATE TABLE zonas(
    id_estado INTEGER,
    id_municipio INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(80) NOT NULL,
    FOREIGN KEY(id_estado, id_municipio) REFERENCES municipios(id_estado, id),
    PRIMARY KEY(id_estado, id_municipio, id)
);
/
CREATE TABLE aplicaciones_delivery (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    app MARCA NOT NULL,
    logo BLOB NOT NULL
);
/
CREATE TABLE garajes (
    id_app INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ubicacion UBICACION NOT NULL,
    id_estado INTEGER NOT NULL,
    id_municipio INTEGER NOT NULL,
    id_zona INTEGER NOT NULL,
    FOREIGN KEY(id_app) REFERENCES aplicaciones_delivery(id),
    FOREIGN KEY(id_estado, id_municipio, id_zona) REFERENCES zonas,
    PRIMARY KEY(id_app, id)
);
/
CREATE TABLE tipos_de_unidades (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY ,
    nombre VARCHAR2(20) NOT NULL,
    distancia_operativa VARCHAR2(20) NOT NULL CHECK (distancia_operativa IN ('ZONA', 'MUNICIPIO', 'ESTADO')),
    velocidad_media NUMBER(5,2),
    cantidad_pedidos NUMBER(2)
);
/
CREATE TABLE unidades_de_transporte (
    id_tipo INTEGER,
    id_app INTEGER,
    id_garaje INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    placa VARCHAR2(8) NOT NULL,
    estado VARCHAR2(20) NOT NULL CHECK (estado IN ('OPERATIVA', 'REPARACION', 'DESCONTINUADA')),
    FOREIGN KEY(id_app, id_garaje) REFERENCES garajes(id_app, id),
    FOREIGN KEY (id_tipo) REFERENCES tipos_de_unidades(id),
    PRIMARY KEY (id_app, id_garaje, id)
);
/
CREATE TABLE registro_de_mantenimiento (
    id_app INTEGER,
    id_garaje INTEGER,
    id_unidad INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    fecha_registro DATE NOT NULL,
    FOREIGN KEY (id_app, id_garaje, id_unidad) REFERENCES unidades_de_transporte(id_app, id_garaje, id),
    PRIMARY KEY (id_app, id_garaje, id_unidad, id)
);
/
CREATE TABLE empresas (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    app MARCA NOT NULL,
    logo BLOB NOT NULL
);
/
CREATE TABLE planes_de_servicio (
    id_app INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    duracion RANGO_TIEMPO NOT NULL,
    precio NUMBER(10,2) NOT NULL,
    cantidad_envios NUMBER(10) NOT NULL,
    modalidad VARCHAR2(20) NOT NULL CHECK (modalidad IN('MENSUAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL')),
    cancelado CANCELACION,
    FOREIGN KEY(id_app) REFERENCES aplicaciones_delivery(id),
    PRIMARY KEY(id_app, id)
);
/
CREATE TABLE ubicaciones_aplicables (
    id_app INTEGER,
    id_estado INTEGER,
    FOREIGN KEY(id_app) REFERENCES aplicaciones_delivery(id),
    FOREIGN KEY(id_estado) REFERENCES estados(id),
    PRIMARY KEY(id_app, id_estado)
);
/
CREATE TABLE contratos (
    id_app INTEGER,
    id_plan INTEGER,
    id_empresa INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    duracion RANGO_TIEMPO NOT NULL,
    porcentaje_descuento NUMBER(5,2),
    cancelado CANCELACION,
    FOREIGN KEY(id_app, id_plan) REFERENCES planes_de_servicio(id_app, id),
    FOREIGN KEY(id_empresa) REFERENCES empresas(id),
    PRIMARY KEY (id_app, id_plan, id_empresa, id)
);
/
CREATE TABLE sucursales (
    id_estado INTEGER,
    id_municipio INTEGER,
    id_zona INTEGER,
    id_empresa INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ubicacion UBICACION NOT NULL,
    FOREIGN KEY(id_estado, id_municipio, id_zona) REFERENCES zonas(id_estado, id_municipio, id),
    FOREIGN KEY(id_municipio) REFERENCES empresas(id),
    PRIMARY KEY (id_empresa, id)
);
/
CREATE TABLE eventos (
    id_empresa INTEGER,
    id_sucursal INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    duracion RANGO_TIEMPO NOT NULL,
    porcentaje_descuento NUMBER(5,2),
    FOREIGN KEY(id_empresa, id_sucursal) REFERENCES sucursales(id_empresa, id),
    PRIMARY KEY (id_empresa, id_sucursal, id)
);
/
CREATE TABLE sectores_de_comercio (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(80) NOT NULL UNIQUE
);
/
CREATE TABLE sectores_de_empresas (
    id_sector INTEGER,
    id_empresas INTEGER,
    FOREIGN KEY(id_sector) REFERENCES sectores_de_comercio(id),
    FOREIGN KEY(id_empresas) REFERENCES empresas(id),
    PRIMARY KEY(id_sector, id_empresas)
);
/
CREATE TABLE productos (
    id_sector INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(150) NOT NULL,
    precio_medio NUMBER(10,2) NOT NULL,
    tiempo_de_preparacion NUMBER(10),
    descripcion VARCHAR2(400)
);
/
CREATE TABLE almacenes (
    id_empresa INTEGER,
    id_sucursal INTEGER,
    id_producto INTEGER,
    disponibilidad NUMBER(5),
    precio NUMBER(10,2),
    FOREIGN KEY(id_empresa, id_sucursal) REFERENCES sucursales(id_empresa, id),
    FOREIGN KEY (id_producto) REFERENCES productos(id),
    PRIMARY KEY (id_empresa, id_sucursal, id_producto)
);
/
CREATE TABLE usuarios (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  primer_nombre VARCHAR2(80) NOT NULL,
  segundo_nombre VARCHAR2(80),
  primer_apellido VARCHAR2(80) NOT NULL,
  segundo_apellido VARCHAR2(80),
  tipo_de_cedula CHAR NOT NULL CHECK (tipo_de_cedula IN ('V', 'E')),
  numero_de_cedula NUMBER(8) NOT NULL,
  email VARCHAR2(150) NOT NULL UNIQUE,
  estado RANGO_TIEMPO NOT NULL
);
/
CREATE TABLE registros (
  id_app INTEGER,
  id_usuario INTEGER,
  FOREIGN KEY(id_app) REFERENCES aplicaciones_delivery(id),
  FOREIGN KEY(id_usuario) REFERENCES usuarios(id),
  PRIMARY KEY(id_app, id_usuario)
);
/
CREATE TABLE direcciones (
    id_estado INTEGER NOT NULL,
    id_municipio INTEGER NOT NULL,
    id_zona INTEGER NOT NULL,
    id_usuario INTEGER NOT NULL,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ubicacion UBICACION NOT NULL,
    descripcion VARCHAR2(400),
    referencia VARCHAR2(1000),
    FOREIGN KEY(id_estado, id_municipio, id_zona) REFERENCES zonas(id_estado, id_municipio, id),
    FOREIGN KEY(id_usuario) REFERENCES usuarios(id),
    PRIMARY KEY(id_estado, id_municipio, id_zona, id_usuario, id)
);
/
CREATE TABLE pedidos (
    id_app INTEGER,
    id_plan INTEGER,
    id_empresa INTEGER,
    id_contrato INTEGER,
    tracking INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado INTEGER,
    id_municipio INTEGER,
    id_zona INTEGER,
    id_usuario INTEGER,
    id_direccion INTEGER,
    duracion RANGO_TIEMPO NOT NULL,
    total NUMBER (15,2) NOT NULL,
    cancelado CANCELACION,
    valoracion NUMBER(1),
    remplazado INTEGER,
    FOREIGN KEY(id_app, id_plan, id_empresa, id_contrato) REFERENCES contratos(id_app, id_plan, id_empresa, id),
    FOREIGN KEY(id_estado, id_municipio, id_zona, id_usuario, id_direccion) REFERENCES direcciones(id_estado, id_municipio, id_zona, id_usuario, id),
    FOREIGN KEY(remplazado) REFERENCES pedidos(tracking)
);
/
CREATE TABLE detalles (
    id_empresa INTEGER,
    id_sucursal INTEGER,
    id_producto INTEGER,
    id_tracking INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    precio_unitario NUMBER(10,2) NOT NULL,
    cantidad NUMBER(5) NOT NULL,
    FOREIGN KEY(id_empresa, id_sucursal, id_producto) REFERENCES almacenes(id_empresa, id_sucursal, id_producto),
    FOREIGN KEY (id_tracking) REFERENCES pedidos(tracking),
    PRIMARY KEY (id_empresa, id_sucursal, id_producto, id_tracking, id)
);
/
CREATE TABLE rutas (
    id_app INTEGER,
    id_garaje INTEGER,
    id_unidad INTEGER,
    id_traking INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    origen SDO_GEOMETRY NOT NULL,
    destino SDO_GEOMETRY NOT NULL,
    proposito VARCHAR2(20) NOT NULL CHECK(proposito IN ('PEDIDO', 'ENVIO', 'RETORNO')),
    cancelado CANCELACION,
    FOREIGN KEY(id_app, id_garaje, id_unidad) REFERENCES unidades_de_transporte(id_app, id_garaje, id),
    FOREIGN KEY(id_traking) REFERENCES pedidos(tracking),
    PRIMARY KEY (id_app, id_garaje, id_unidad, id_traking, id)
);
/