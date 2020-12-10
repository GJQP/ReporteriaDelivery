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

-- SIMULACION
CREATE OR REPLACE PROCEDURE update_sim_time(p_descripcion VARCHAR2) IS
    d DATE;
    ids INTEGER;
BEGIN
    UPDATE
        sim_time SM
    SET
        SM.TIEMPO.FECHA_FIN = SYSDATE
    WHERE
          SM.TIEMPO.FECHA_FIN IS NULL
    RETURNING
        SM.TIEMPO.FECHA_INICIO INTO d;
    INSERT INTO
        sim_time
    VALUES
        (DEFAULT, RANGO_TIEMPO(d), p_descripcion)
    RETURNING
        id INTO ids;
    DBMS_OUTPUT.PUT_LINE('# Se ha actualizado la fecha de la simulación de ' || d || ' a ' || d + 1/4/24 || ' en ' || p_descripcion);
END;

CREATE OR REPLACE FUNCTION sim_date RETURN DATE IS
    d DATE;
BEGIN
    SELECT SM.TIEMPO.FECHA_INICIO  INTO d FROM sim_time SM WHERE SM.TIEMPO.FECHA_FIN IS NULL;
    RETURN d;
END;

--CONTRATOS

--TODO VALIDAR SI LA EMPRESA TIENE SUCURSALES APLICABLES PARA ENTRAR EN ESTA OPCION
--TODO VALIDAR SI LA APP TIENE GARAJES APLICABLES PARA ENTRAR EN ESTA OPCION
--UNA EMPRESA NO CONTRATADA ES AQUELLA DONDE EL ESTADO DEL GARAJE DE LAS APPS Y UNA SUCURSAL COINCIDA
CREATE OR REPLACE FUNCTION obtener_empresa_no_contratada(id_app_busqueda aplicaciones_delivery.id%TYPE, fecha_sim DATE DEFAULT SYSDATE)
RETURN empresas.id%TYPE
IS
    rand_empresa empresas.id%TYPE;
BEGIN
    SELECT e.id
    INTO rand_empresa
    FROM
    (SELECT id_empresa, ps.id FROM planes_de_servicio ps
    JOIN contratos c2 ON ps.id_app = c2.id_app AND ps.id = c2.id_plan
    WHERE ps.id_app = id_app_busqueda
            AND TREAT(ps.duracion AS rango_tiempo).fecha_fin > fecha_sim
            AND (
                    ps.cancelado IS NULL
                    OR
                    TREAT(ps.cancelado AS cancelacion).fecha_cancelacion > fecha_sim
                )
            AND(
                c2.cancelado IS NULL
                    OR
                    TREAT(c2.cancelado AS cancelacion).fecha_cancelacion > fecha_sim
                )
        ) pc
    RIGHT JOIN empresas e ON e.id = pc.id_empresa
    WHERE pc.id_empresa IS NULL
    ORDER BY dbms_random.value
    FETCH FIRST ROW ONLY;

    RETURN rand_empresa;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;

CREATE OR REPLACE PROCEDURE crear_contrato(in_id_app aplicaciones_delivery.id%TYPE,in_id_plan planes_de_servicio.id%TYPE, in_id_empresa empresas.id%TYPE)
IS
    cantidad_contratos_anteriores NUMBER;
    descuento contratos.porcentaje_descuento%TYPE;
    BEGIN

    dbms_output.PUT_LINE('## SE VERIFICAN LOS DESCUENTOS POR ANTIGÜEDAD');
    SELECT COUNT(1) INTO cantidad_contratos_anteriores
    FROM contratos
    WHERE id_app=in_id_app AND id_empresa = in_id_empresa;

    IF cantidad_contratos_anteriores > 4 THEN
        dbms_output.PUT_LINE('### APLICA PARA DESCUENTO');
        descuento := ROUND(dbms_random.VALUE(0,30),2);
    ELSIF cantidad_contratos_anteriores > 2 THEN
        dbms_output.PUT_LINE('### APLICA PARA DESCUENTO');
        descuento := ROUND(dbms_random.VALUE(0,10),2);
    ELSE
        dbms_output.PUT_LINE('### NO APLICA PARA DESCUENTO');
        descuento := 0;
    END IF;

    dbms_output.PUT_LINE('## SE GENERA UN CONTRATO DE LA APP ' || in_id_app ||
                         ' CON LA EMPRESA ' || in_id_empresa ||
                         ' CON EL PLAN ' || in_id_plan);
           INSERT INTO contratos
           VALUES (
                   in_id_app,
                   in_id_plan,
                   in_id_empresa,
                   DEFAULT,
                   RANGO_TIEMPO(SYSDATE,SYSDATE + ROUND(dbms_random.VALUE(0,365))),
                   descuento,
                   NULL
                  );

    END;

CREATE OR REPLACE PROCEDURE crear_plan_servicio(in_app_id aplicaciones_delivery.id%TYPE, in_id_empresa empresas.id%TYPE DEFAULT NULL)
IS
    random_val NUMBER;
    plan_modalidad planes_de_servicio.modalidad%TYPE;
    id_nuevo_plan planes_de_servicio.id%TYPE;
    BEGIN

        random_val := dbms_random.VALUE(0,1);

        IF random_val < 0.25 THEN
            plan_modalidad := 'MENSUAL';
        ELSIF random_val < 0.5 THEN
            plan_modalidad := 'TRIMESTRAL';
        ELSIF random_val < 0.75 THEN
            plan_modalidad := 'SEMESTRAL';
        ELSE
            plan_modalidad := 'ANUAL';
        END IF;


        INSERT INTO planes_de_servicio VALUES
        (in_app_id,
         DEFAULT,
         RANGO_TIEMPO(SYSDATE,SYSDATE + ROUND(dbms_random.VALUE(0,365))),
         ROUND(dbms_random.VALUE(50,4000),2), --PRECIO
         ROUND(dbms_random.VALUE(10,800)), --CANTIDAD DE ENVIO
         plan_modalidad, --MODALIDAD
         NULL --cancelacion
        )
        RETURNING id INTO id_nuevo_plan;

        IF in_id_empresa IS NOT NULL THEN
            crear_contrato(in_app_id,id_nuevo_plan,in_id_empresa);
        ELSE
            dbms_output.PUT_LINE('## SE SELECCIONA UNA EMPRESA SIN CONTRATO VIGENTE');
            crear_contrato(in_app_id,id_nuevo_plan,obtener_empresa_no_contratada(in_app_id));
        END IF;


    END;

CREATE OR REPLACE PROCEDURE modulo_contratos(fecha_sim DATE DEFAULT SYSDATE)
IS
    id_app_rand aplicaciones_delivery.id%TYPE;
    id_plan_selec planes_de_servicio.id%TYPE;
    id_empresa_rand empresas.id%TYPE;

    CURSOR cursor_planes_app(id_app_rand aplicaciones_delivery.id%TYPE)
        IS
        SELECT ps.id
            FROM planes_de_servicio ps
            WHERE ps.id_app = id_app_rand
            AND TREAT(duracion AS rango_tiempo).fecha_fin > SYSDATE
            AND (
                    cancelado IS NULL
                    OR
                    TREAT(cancelado AS cancelacion).fecha_cancelacion > SYSDATE
                )
            ORDER BY dbms_random.value
            FETCH FIRST ROW ONLY;

    BEGIN
    --se obtiene la app
    dbms_output.PUT_LINE('# GESTION CONTRATOS');

    dbms_output.PUT_LINE('## SE SELECCIONA UNA APLICACION AL AZAR');
    SELECT id
        INTO id_app_rand
        FROM aplicaciones_delivery
        ORDER BY DBMS_RANDOM.VALUE
        FETCH FIRST ROW ONLY;

    dbms_output.PUT_LINE('## SE VERIFICAN LOS PLANES DE LA APP ' || id_app_rand);

    OPEN cursor_planes_app(id_app_rand);
    --se obtiene un plan al azar
    FETCH cursor_planes_app INTO id_plan_selec;

    --NO EXISTEN PLANES VIGENTES O ESTAN CANCELADOS
    IF cursor_planes_app%NOTFOUND = TRUE THEN
        dbms_output.PUT_LINE('### NO EXISTEN PLANES VIGENTES PARA LA APLICACION');
        dbms_output.PUT_LINE('## SE DECIDE GENERAR UN NUEVO PLAN DE SERVICIO A LA APP ' || id_app_rand);
        crear_plan_servicio(id_app_rand);
    ELSE
    dbms_output.PUT_LINE('## SE VERIFICAN SI HAY EMPRESAS CONTRADAS');
    id_empresa_rand := obtener_empresa_no_contratada(id_app_rand,fecha_sim);
        IF id_empresa_rand = 0 THEN
            --se usa el plan al azar
            dbms_output.PUT_LINE('### NO HAY PROVEEDORES A CONTRATARSE');
            dbms_output.PUT_LINE('## SE SELECCIONA UN PLAN PARA EVALUAR UN CONTRATO VIGENTE');
            IF dbms_random.VALUE(0,1) > 0.5 THEN
                dbms_output.PUT_LINE('### SE DECIDE CANCELAR UN CONTRATO DEL PLAN ' || id_plan_selec);
                --CANCELAR UN CONTRATO AL AZAR DE DICHO PLAN
                UPDATE contratos SET cancelado = cancelacion(fecha_sim,'Contrato no factible por revisión programada')
                WHERE id = (
                    SELECT id
                    FROM contratos
                    WHERE id_plan = id_plan_selec
                    ORDER BY dbms_random.value
                    FETCH FIRST ROW ONLY
                    );
            ELSE
                dbms_output.PUT_LINE('### NO SE DECIDE CANCELAR UN CONTRATO DEL PLAN' || id_plan_selec);
            END IF;
        ELSIF dbms_random.value(0,1) > 0.8 THEN
            dbms_output.PUT_LINE('### HAY PROVEEDORES A CONTRATARSE');
            dbms_output.PUT_LINE('## SE DECIDE GENERAR UN NUEVO PLAN DE SERVICIO A LA EMPRESA ' || id_empresa_rand);
            crear_plan_servicio(id_app_rand,id_empresa_rand);
        ELSE
            dbms_output.PUT_LINE('### HAY PROVEEDORES A CONTRATARSE');
            dbms_output.PUT_LINE('### SE DECIDE GENERAR UN CONTRATO EN BASE EL PLAN ' || id_plan_selec || ' A LA EMPRESA ' || id_empresa_rand);
            crear_contrato(id_app_rand,id_plan_selec,id_empresa_rand);
        END IF;

    END IF;

    CLOSE cursor_planes_app;
    END;

--FIN CONTRATOS

--INICIO MANTENIMIENTO

--SE PUEDE HACER POR APP
CREATE OR REPLACE PROCEDURE modulo_mantenimiento(fecha_sim DATE DEFAULT SYSDATE, in_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
IS
    DIAS_PARA_DESCONTINUAR CONSTANT NUMBER := 30;
    DIAS_PARA_REALIZAR_MANT_PREV CONSTANT NUMBER := 90;

    unidad unidades_de_transporte%ROWTYPE;
    ult_mantenimiento registro_de_mantenimiento%ROWTYPE;
    CURSOR unidades_app(in_id_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
    IS
        SELECT *
        FROM unidades_de_transporte ut
        WHERE in_id_app IS NULL OR ut.id_app = in_id_app;

BEGIN

    OPEN unidades_app(in_app);
    FOR unidad IN unidades_app
    LOOP
        dbms_output.PUT_LINE('## SE VERIFICA EL ESTADO DE LA UNIDAD');
        IF unidad.estado = 'REPARACION' THEN
            dbms_output.PUT_LINE('### LA UNIDAD ESTÁ DAÑADA SE DECIDE SI REALIZAR O NO EL MANTENIMIENTO A LA UNIDAD');
            IF dbms_random.VALUE(0,1) > 0.5 THEN

                dbms_output.PUT_LINE('## SE DECIDE SI REALIZAR MANTENIMIENTO CORRECTIVO ' ||
                                     'O DESCONTINUAR LA UNIDAD');

                SELECT * INTO ult_mantenimiento
                FROM registro_de_mantenimiento
                WHERE id_app=unidad.id_app
                  AND id_garaje=unidad.id_garaje
                  AND id_unidad=unidad.id
                ORDER BY id DESC
                FETCH FIRST ROW ONLY;

                IF  ult_mantenimiento.fecha_registro - fecha_sim
                       >
                   DIAS_PARA_DESCONTINUAR THEN
                    dbms_output.PUT_LINE('### SE DECIDE A NO REALIZAR MANTENIMIENTO Y DESCONTINUAR LA UNIDAD');

                    UPDATE unidades_de_transporte SET estado = 'DESCONTINUADA'
                    WHERE id = unidad.id
                        AND id_garaje=unidad.id_garaje
                        AND id_app=unidad.id_app;

                END IF;

            ELSE
                dbms_output.PUT_LINE('### SE DECIDE NO REALIZAR MANTENIMIENTO A LA UNIDAD Y CONTINUARA EN MANTENIMIENTO');
            END IF;
        ELSIF unidad.estado = 'OPERATIVA' THEN

            SELECT * INTO ult_mantenimiento
                FROM registro_de_mantenimiento
                WHERE id_app=unidad.id_app
                  AND id_garaje=unidad.id_garaje
                  AND id_unidad=unidad.id
                ORDER BY id DESC
                FETCH FIRST ROW ONLY;

            dbms_output.PUT_LINE('### LA UNIDAD ESTÁ OPERATIVA');
            dbms_output.PUT_LINE('## SE VERIFICA SI REQUIERE DE MANTENIMIENTO PREVENTIVO');
            IF ult_mantenimiento.fecha_registro - fecha_sim > DIAS_PARA_REALIZAR_MANT_PREV THEN
                dbms_output.PUT_LINE('### SE REALIZA MANTENIMIENTO PREVENTIVO' ||
                                     'A LA UNIDAD');

                UPDATE unidades_de_transporte SET estado = 'REPARACION'
                    WHERE id = unidad.id
                        AND id_garaje=unidad.id_garaje
                        AND id_app=unidad.id_app;
            ELSE
                dbms_output.PUT_LINE('### SE MANTIENE OPERATIVA LA UNIDAD');
            END IF;
        END IF;
    END LOOP;

END;

--FIN MANTENIMIENTO

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

