-- CREATE TABLES
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
    app MARCA NOT NULL
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
    nombre VARCHAR2(20) NOT NULL CHECK (nombre IN ('CAMIONETA', 'BICICLETA', 'MOTO','CARRO','DRONE')),
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
CREATE TABLE sectores_de_comercio (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(80) NOT NULL UNIQUE
);
/
CREATE TABLE empresas (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    empresa MARCA NOT NULL,
    id_sector INTEGER NOT NULL,
    FOREIGN KEY (id_sector) REFERENCES sectores_de_comercio(id)
);
/
CREATE TABLE planes_de_servicio (
    id_app INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    duracion RANGO_TIEMPO NOT NULL,
    precio NUMBER(10,2) NOT NULL,
    cantidad_envios NUMBER(10) NOT NULL,
    modalidad VARCHAR2(20) NOT NULL CHECK (modalidad IN('MENSUAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL')),
    cancelado CANCELACION DEFAULT NULL,
    FOREIGN KEY(id_app) REFERENCES aplicaciones_delivery(id),
    PRIMARY KEY(id_app, id)
);
/
CREATE TABLE ubicaciones_aplicables (
    id_app INTEGER,
    id_plan INTEGER,
    id_estado INTEGER,
    FOREIGN KEY(id_app, id_plan) REFERENCES planes_de_servicio(id_app, id),
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
    cancelado CANCELACION DEFAULT NULL,
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
    FOREIGN KEY(id_empresa) REFERENCES empresas(id),
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
CREATE TABLE productos (
    id_sector INTEGER,
    id_empresa INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(150) NOT NULL,
    precio NUMBER(10,2) NOT NULL,
    tiempo_de_preparacion NUMBER(10) DEFAULT 0,
    descripcion VARCHAR2(400),
    FOREIGN KEY (id_sector) REFERENCES sectores_de_comercio(id),
    FOREIGN KEY (id_empresa) REFERENCES empresas(id)
);
/
CREATE TABLE almacenes (
    id_empresa INTEGER,
    id_sucursal INTEGER,
    id_producto INTEGER,
    disponibilidad NUMBER(5),
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
  estado RANGO_TIEMPO NOT NULL,
  foto BLOB
);
/
CREATE TABLE registros (
  id_app INTEGER,
  id_usuario INTEGER,
  registro RANGO_TIEMPO NOT NULL,
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