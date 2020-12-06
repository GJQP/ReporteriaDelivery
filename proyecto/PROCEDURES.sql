-- PROCEDURES DE INSERTS
CREATE OR REPLACE PROCEDURE insertar_app_delivery(
    nombre VARCHAR2,
    rif VARCHAR2,
    fecha_registro DATE,
    nombre_img_logo VARCHAR2)
IS
   l_size NUMBER;
   l_file_ptr BFILE;
   l_blob BLOB;
BEGIN
   l_file_ptr := bfilename('IMGDIR_APPS', nombre_img_logo);
   dbms_lob.fileopen(l_file_ptr);
   l_size := dbms_lob.getlength(l_file_ptr);
   INSERT INTO aplicaciones_delivery (id, app) VALUES (DEFAULT, MARCA(nombre, rif, fecha_registro)) returning TREAT(app as MARCA).LOGO into l_blob;
   dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
   COMMIT;
   dbms_lob.close(l_file_ptr);
END;

CREATE OR REPLACE PROCEDURE insertar_empresa(
    nombre VARCHAR2, rif VARCHAR2,
    fecha_registro DATE ,
    nombre_img_logo VARCHAR2,
    id_sector INTEGER)
IS
    l_size NUMBER;
    l_file_ptr BFILE;
    l_blob BLOB;
BEGIN
   l_file_ptr := bfilename('IMGDIR_EMPRESAS', nombre_img_logo);
   dbms_lob.fileopen(l_file_ptr);
   l_size := dbms_lob.getlength(l_file_ptr);
   INSERT INTO empresas (id, empresa, id_sector) VALUES (DEFAULT, MARCA(nombre, rif, fecha_registro), id_sector) returning TREAT(empresa AS MARCA).LOGO into l_blob;
   dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
   COMMIT;
   dbms_lob.close(l_file_ptr);
END;
/

CREATE OR REPLACE PROCEDURE insertar_usuario(
    p_nombre VARCHAR2,
    s_nombre VARCHAR2,
    p_apellido VARCHAR2,
    s_apellido VARCHAR2,
    t_cedula CHAR,
    n_cedula NUMBER,
    u_email VARCHAR2,
    nombre_img_foto VARCHAR2)
IS
    l_size NUMBER;
    l_file_ptr BFILE;
    l_blob BLOB;
BEGIN
   l_file_ptr := bfilename('IMGDIR_USUARIOS', nombre_img_foto);
   dbms_lob.fileopen(l_file_ptr);
   l_size := dbms_lob.getlength(l_file_ptr);
   INSERT INTO
       USUARIOS (ID, PRIMER_NOMBRE, SEGUNDO_NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO, TIPO_DE_CEDULA, NUMERO_DE_CEDULA, EMAIL, ESTADO, FOTO)
   VALUES
        (DEFAULT, p_nombre, s_nombre, p_apellido, s_apellido, t_cedula, n_cedula, u_email, RANGO_TIEMPO(SYSDATE), empty_blob()) returning FOTO into l_blob;
   dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
   COMMIT;
   dbms_lob.close(l_file_ptr);
END;
/

-- PROCEDURES OTROS
/*CREATE OR REPLACE PROCEDURE validar_pedidos(
    in_fecha IN DATE,
    in_zona VARCHAR2
)
IS
    cur SYS_REFCURSOR;

    nombre_app VARCHAR2(30);
    counting VARCHAR2(30);
    nombre_zona VARCHAR2(30);
    id_zona NUMBER;

    records NUMBER(1);
BEGIN
    records:= 0;
    SELECT z.id INTO id_zona FROM zonas z WHERE z.nombre = in_zona;
    DBMS_OUTPUT.PUT_LINE('ID zona '|| id_zona);

    OPEN cur FOR
        SELECT app.marca.nombre,
               COUNT(pe.tracking) AS "Pedidos"
        FROM pedidos pe, direcciones dir, zonas zo, aplicaciones_delivery app, usuarios u
        WHERE pe.id_direccion = dir.id
          AND dir.id_zona = zo.id
          AND zo.id = id_zona
          AND zo.nombre = in_zona
          AND u.id = dir.id_usuario
          AND app.id = u.id_app
          AND TRIM(pe.fechas.FECHA_INICIO) = TRIM(IN_FECHA)
        GROUP BY app.nombre;

    LOOP
        FETCH cur INTO nombre_app, counting;
        exit when cur%notfound;
        dbms_output.put_line('RESULTADO: ' || nombre_app || ' generó ' || counting || ' pedido(s) en ' || in_zona || ' para el ' || TO_CHAR(in_fecha, 'yyyy/mm/dd') );
        records := 1;
    END LOOP;
    CLOSE cur;

    IF (records = 0) THEN
       DBMS_OUTPUT.PUT_LINE('NO EXISTEN REGISTROS PARA LA BÚSQUEDA SOLICITADA');
    END IF;

    EXCEPTION
    WHEN no_data_found THEN
        DBMS_OUTPUT.PUT_LINE('NO EXISTE LA ZONA SOLICITADA');
END;*/
/

