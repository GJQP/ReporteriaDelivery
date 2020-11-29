CREATE TABLE estados(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
);

CREATE TABLE sumario (
    id_estado INTEGER,
    id INTEGER,
    fecha DATE,
    deliverys NUMBER(10),
    acumulado NUMBER(10),
    FOREIGN KEY(id_estado) REFERENCES estados(id),
    PRIMARY KEY(id_estado, id)
);
