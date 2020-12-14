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
        SM.TIEMPO = rango_tiempo(SM.TIEMPO.fecha_inicio,SM.TIEMPO.fecha_inicio+15/24/60)
    WHERE
          SM.TIEMPO.FECHA_FIN IS NULL
    RETURNING
        SM.TIEMPO.FECHA_INICIO INTO d;
    INSERT INTO
        sim_time
    VALUES
        (DEFAULT, RANGO_TIEMPO(d+15/24/60), p_descripcion)
    RETURNING
        id INTO ids;
    --DBMS_OUTPUT.PUT_LINE('# Se ha actualizado la fecha de la simulación de ' || d || ' a ' || d + 1/4/24 || ' en ' || p_descripcion);
END;

CREATE OR REPLACE FUNCTION sim_date RETURN DATE IS
    d DATE;
BEGIN
    SELECT SM.TIEMPO.FECHA_INICIO  INTO d FROM sim_time SM WHERE SM.TIEMPO.FECHA_FIN IS NULL;
    RETURN d;
END;

--CONTRATOS

--TODO VALIDAR SI LA EMPRESA TIENE SUCURSALES APLICABLES PARA ENTRAR EN ESTA OPCION
--UNA EMPRESA NO CONTRATADA ES AQUELLA DONDE EL ESTADO DEL GARAJE DE LAS APPS Y UNA SUCURSAL COINCIDA
CREATE OR REPLACE FUNCTION obtener_empresa_no_contratada(id_app_busqueda aplicaciones_delivery.id%TYPE, fecha_sim DATE DEFAULT SIM_DATE())
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
    ORDER BY dbms_random.value()
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
                   RANGO_TIEMPO(SIM_DATE(),SIM_DATE() + ROUND(dbms_random.VALUE(0,365))),
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
         RANGO_TIEMPO(SIM_DATE(),SIM_DATE() + ROUND(dbms_random.VALUE(0,365))),
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

CREATE OR REPLACE PROCEDURE modulo_contratos(fecha_sim DATE DEFAULT SIM_DATE())
IS
    id_app_rand aplicaciones_delivery.id%TYPE;
    id_plan_selec planes_de_servicio.id%TYPE;
    id_empresa_rand empresas.id%TYPE;

    CURSOR cursor_planes_app(id_app_rand aplicaciones_delivery.id%TYPE)
        IS
        SELECT ps.id
            FROM planes_de_servicio ps
            WHERE ps.id_app = id_app_rand
            AND TREAT(duracion AS rango_tiempo).fecha_fin > SIM_DATE()
            AND (
                    cancelado IS NULL
                    OR
                    TREAT(cancelado AS cancelacion).fecha_cancelacion > SIM_DATE()
                )
            ORDER BY dbms_random.value()
            FETCH FIRST ROW ONLY;

    BEGIN
    --se obtiene la app
    dbms_output.PUT_LINE('# GESTION CONTRATOS');

    dbms_output.PUT_LINE('## SE SELECCIONA UNA APLICACION AL AZAR');
    SELECT id
        INTO id_app_rand
        FROM aplicaciones_delivery
        ORDER BY DBMS_RANDOM.VALUE()
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
                    ORDER BY dbms_random.value()
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
CREATE OR REPLACE PROCEDURE modulo_mantenimiento(fecha_sim DATE DEFAULT SIM_DATE(), in_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
IS
    DIAS_PARA_DESCONTINUAR CONSTANT NUMBER := 30;
    DIAS_PARA_REALIZAR_MANT_PREV CONSTANT NUMBER := 90;

    unidad unidades_de_transporte%ROWTYPE;
    ult_mantenimiento registro_de_mantenimiento%ROWTYPE;
    CURSOR unidades_app(in_id_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
    IS
        SELECT *
        FROM unidades_de_transporte ut
        WHERE in_id_app IS NULL OR ut.id_app = in_id_app
        ORDER BY dbms_random.value();

    CURSOR mant_unidad(unidad unidades_app%ROWTYPE)
    IS
        SELECT *
            INTO ult_mantenimiento
            FROM registro_de_mantenimiento
            WHERE id_app=unidad.id_app
              AND id_garaje=unidad.id_garaje
              AND id_unidad=unidad.id
            ORDER BY id DESC
            FETCH FIRST ROW ONLY;

BEGIN

    FOR unidad IN unidades_app(in_app)
    LOOP
        dbms_output.PUT_LINE('## SE VERIFICA EL ESTADO DE LA UNIDAD '|| unidad.id);

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

            dbms_output.PUT_LINE('### LA UNIDAD ESTÁ OPERATIVA');

            OPEN mant_unidad(unidad);
            FETCH mant_unidad INTO ult_mantenimiento;

            IF mant_unidad%NOTFOUND AND dbms_random.VALUE(0,1) > 0.2 THEN
                dbms_output.PUT_LINE('### SE REALIZA MANTENIMIENTO PREVENTIVO ' ||
                                     'A LA UNIDAD');

                UPDATE unidades_de_transporte SET estado = 'REPARACION'
                    WHERE id = unidad.id
                        AND id_garaje=unidad.id_garaje
                        AND id_app=unidad.id_app;

            ELSE
               dbms_output.PUT_LINE('## SE VERIFICA SI REQUIERE DE MANTENIMIENTO PREVENTIVO');
            IF ult_mantenimiento.fecha_registro - fecha_sim > DIAS_PARA_REALIZAR_MANT_PREV THEN
                dbms_output.PUT_LINE('### SE REALIZA MANTENIMIENTO PREVENTIVO' ||
                                     ' A LA UNIDAD');

                UPDATE unidades_de_transporte SET estado = 'REPARACION'
                    WHERE id = unidad.id
                        AND id_garaje=unidad.id_garaje
                        AND id_app=unidad.id_app;
            ELSE
                dbms_output.PUT_LINE('### SE MANTIENE OPERATIVA LA UNIDAD');
            END IF;

            END IF;

            CLOSE mant_unidad;

        END IF;
    END LOOP;

END;

--FIN MANTENIMIENTO

-- PEDIDOS

CREATE OR REPLACE FUNCTION sucursal_factible(in_id_app aplicaciones_delivery.id%TYPE,
                    in_id_empresa empresas.id%TYPE,
                    in_direccion direcciones%ROWTYPE)
RETURN sucursales.id%TYPE
IS
    id_sucursal sucursales.id%TYPE;
    id_zona NUMBER;
    id_municipio NUMBER;
    id_estado NUMBER;
BEGIN
        SELECT DISTINCT s.id,
           DECODE(s.id_zona,DECODE(in_direccion.id_zona,g.id_zona,s.id_zona,0),s.id_zona,0) as id_zona,
           DECODE(s.id_municipio,DECODE(in_direccion.id_municipio,g.id_municipio,s.id_municipio,0),s.id_municipio,0) as id_municipio,
           DECODE(s.id_estado,DECODE(in_direccion.id_estado,g.id_estado,s.id_estado,0),s.id_estado,0) as id_estado
        --INTO sucursal_factible.id_sucursal, sucursal_factible.id_zona, sucursal_factible.id_municipio, sucursal_factible.id_estado
        FROM sucursales s
        JOIN garajes g ON s.id_estado = g.id_estado
        --JOIN direcciones d ON g.id_estado = d.id_estado
        JOIN unidades_de_transporte udt ON g.id_app = udt.id_app AND g.id = udt.id_garaje
        JOIN tipos_de_unidades tdu ON udt.id_tipo = tdu.id
        JOIN almacenes a2 ON s.id_empresa = a2.id_empresa AND s.id = a2.id_sucursal
        WHERE g.id_app = in_id_app --APP
        --AND d.id_usuario = in_id_usuario --USUARIO
        AND s.id_empresa = in_id_empresa--EMPRESA
        AND 0 < (SELECT COUNT(disponibilidad) FROM almacenes al WHERE al.id_sucursal = a2.id_sucursal) --DISPONIBILIDAD
        AND udt.estado = 'OPERATIVA'
        AND (
            ( s.id_zona = g.id_zona AND s.id_zona = in_direccion.id_zona ) --ZONA
            OR
            ( s.id_municipio = g.id_municipio AND s.id_municipio = in_direccion.id_municipio AND tdu.distancia_operativa NOT LIKE 'ZONA')--MUNICIPIO
            OR
            (tdu.distancia_operativa LIKE 'ESTADO')--ESTADO
            )--ALCANCE
        ORDER BY id_zona DESC, id_municipio DESC, id_estado DESC
        FETCH FIRST ROW ONLY;

        RETURN id_sucursal;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            RETURN 0;
END;

CREATE OR REPLACE FUNCTION obtener_descuentos(empresa_id empresas.id%TYPE,sucursal_id sucursales.id%TYPE)
RETURN eventos.porcentaje_descuento%TYPE
IS
    res eventos.porcentaje_descuento%TYPE := 0;
BEGIN

    SELECT e.porcentaje_descuento
    INTO res
    FROM eventos e
    WHERE id_empresa = empresa_id AND id_sucursal = sucursal_id
      AND e.duracion.fecha_inicio >= SIM_DATE()
      AND e.duracion.fecha_fin IS NULL
    FETCH FIRST ROW ONLY;

    RETURN res;

    EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN res;

END;

CREATE OR REPLACE PROCEDURE crear_pedido_aleatorio(
    app_id aplicaciones_delivery.id%TYPE,
    plan_id planes_de_servicio.id%TYPE,
    empresa_id empresas.id%TYPE,
    contrato_id contratos.id%TYPE,
    estado_id estados.id%TYPE,
    municipio_id municipios.id%TYPE,
    zona_id zonas.id%TYPE,
    usuario_id usuarios.id%TYPE,
    direccion_id direcciones.id%TYPE,
    sucursal_id sucursales.id%TYPE
)
IS

    CURSOR disponibilidad_producto(
        in_cur_id_empresa empresas.id%TYPE,
        in_cur_id_sucursal sucursales.id%TYPE)
        IS
        SELECT p.id,p.precio, a.disponibilidad
        FROM almacenes a
        JOIN productos p ON a.id_producto = p.id
        WHERE a.id_empresa = in_cur_id_empresa
        AND a.id_sucursal = in_cur_id_sucursal;

    TYPE item IS RECORD(
        producto_id productos.id%TYPE,
        cantidad detalles.cantidad%TYPE,
        precio_unitario detalles.precio_unitario%TYPE
    );

    TYPE carrito IS TABLE OF item;

    descuento eventos.porcentaje_descuento%TYPE;

    producto disponibilidad_producto%ROWTYPE;

    detalle_orden carrito := carrito();

    total_orden NUMBER := 0;

    pedido pedidos.tracking%TYPE;
BEGIN

    descuento := obtener_descuentos(empresa_id,sucursal_id);
    FOR producto IN disponibilidad_producto(empresa_id,sucursal_id)
    LOOP
        IF producto.disponibilidad > 0 THEN
            detalle_orden.extend();

            --aux.cantidad := FLOOR(dbms_random.VALUE(1,producto.disponibilidad));
            --aux.precio_unitario := producto.precio;

            detalle_orden(detalle_orden.last).producto_id := producto.id;
            detalle_orden(detalle_orden.last).cantidad := FLOOR(dbms_random.VALUE(1,producto.disponibilidad));
            detalle_orden(detalle_orden.last).precio_unitario := producto.precio * (1 - descuento);

            total_orden:= total_orden + producto.precio * detalle_orden(detalle_orden.last).cantidad * (1 - descuento);
        END IF;
    END LOOP;

    IF descuento > 0 THEN
        dbms_output.PUT_LINE('### EL PEDIDO HA APLICADO UN DESCUENTO DE ' || descuento);
    END IF;

    INSERT INTO pedidos VALUES (app_id,
                                plan_id,
                                empresa_id,
                                contrato_id,
                                DEFAULT,
                                estado_id,
                                municipio_id,
                                zona_id,
                                usuario_id,
                                direccion_id,
                                rango_tiempo(SIM_DATE()),
                                total_orden,
                                NULL,
                                NULL,
                                NULL
                                )
    RETURNING tracking INTO pedido;

    FOR l_orden IN detalle_orden.first..detalle_orden.last
    LOOP
        INSERT INTO detalles VALUES (empresa_id,
                                     sucursal_id,
                                     detalle_orden(l_orden).producto_id,
                                     pedido,
                                     DEFAULT,
                                     detalle_orden(l_orden).precio_unitario,
                                     detalle_orden(l_orden).cantidad);

        UPDATE almacenes SET disponibilidad = disponibilidad - detalle_orden(l_orden).cantidad
        WHERE id_sucursal = sucursal_id AND id_empresa = empresa_id AND id_producto = producto.id;
    END LOOP;


END;

CREATE OR REPLACE FUNCTION obtener_usuario_azar_pedido
RETURN usuarios.id%TYPE
IS
BEGIN

    FOR l_usuario IN (
        SELECT u.id,r.id_app,u.primer_nombre,ad.app.nombre
        FROM usuarios u
        INNER JOIN registros r ON u.id = r.id_usuario
        INNER JOIN aplicaciones_delivery ad ON ad.id = r.id_app
        ORDER BY dbms_random.VALUE()
        )
    LOOP
         dbms_output.PUT_LINE('## SE SELECCIONA LA USUARIO DE ID '|| l_usuario.id);
         dbms_output.PUT_LINE('## SE VERIFICA SI TIENE APPS CON CONTRATOS VIGENTES');
         FOR l_app IN (
             SELECT DISTINCT r.id_app
            FROM registros r
            INNER JOIN contratos c2 ON r.id_app = c2.id_app
            INNER JOIN planes_de_servicio pds ON c2.id_app = pds.id_app AND c2.id_plan = pds.id
            WHERE r.id_usuario = l_usuario.id
            AND c2.duracion.fecha_fin >= SIM_DATE() AND c2.cancelado IS NULL
            AND pds.duracion.fecha_fin >= SIM_DATE() AND pds.cancelado IS NULL
            FETCH FIRST ROW ONLY)
         LOOP
             RETURN l_usuario.id;
         END LOOP;
         dbms_output.PUT_LINE('## EL USUARIO' || l_usuario.id ||' NO TIENE APPS CON CONTRATOS VIGENTES');
    END LOOP;

    RETURN 0;

END;

CREATE OR REPLACE PROCEDURE modulo_pedido
IS

    CURSOR empresas_elegibles(cur_app_id aplicaciones_delivery.id%TYPE, cur_usuario_id usuarios.id%TYPE)
    IS
    SELECT c2.id_app,c2.id_plan,c2.id_empresa,c2.id as id_contrato
    FROM contratos c2
    JOIN planes_de_servicio pds ON pds.id_app = c2.id_app AND pds.id = c2.id_plan
    JOIN ubicaciones_aplicables ua ON pds.id_app = ua.id_app AND pds.id = ua.id_plan

    WHERE (pds.duracion.fecha_fin > SIM_DATE() OR pds.duracion.fecha_fin IS NULL) --PLAN VIGENTE
    AND (c2.duracion.fecha_fin > SIM_DATE() OR c2.duracion.fecha_fin IS NULL) --CONTRATO VIGENTE
    AND ua.id_estado IN (SELECT d.id_estado FROM direcciones d WHERE d.id_usuario = cur_usuario_id) -- DEL ESTADO DE LAS DIRECCIONES DE LA PERSONA
    AND c2.id_app = cur_app_id;-- DE LA APP

    rand_usuario_id usuarios.id%TYPE;
    app_id aplicaciones_delivery.id%TYPE;
    cont_id contratos.id%TYPE;

    direccion_usuario direcciones%ROWTYPE;

    fk_pedidos_sucursal empresas_elegibles%ROWTYPE;

    id_suc sucursales.id%TYPE := 0;

BEGIN

    --SELECCIONA UN USUARIO AL AZAR REGISTRADO
    rand_usuario_id := obtener_usuario_azar_pedido();

    IF rand_usuario_id = 0 THEN
        GOTO fin;
    END IF;
    --CONSULTA ALGUNA APLICACION VALIDA AL AZAR DONDE ESTE REGISTRADO
    SELECT r.id_app
    INTO app_id
    FROM registros r
    INNER JOIN contratos c2 ON r.id_app = c2.id_app
    INNER JOIN planes_de_servicio pds ON c2.id_app = pds.id_app AND c2.id_plan = pds.id
    WHERE r.id_usuario = rand_usuario_id
    AND c2.duracion.fecha_fin >= SIM_DATE() AND c2.cancelado IS NULL
    AND pds.duracion.fecha_fin >= SIM_DATE() AND pds.cancelado IS NULL
    ORDER BY dbms_random.VALUE()
    FETCH FIRST ROW ONLY;

    dbms_output.PUT_LINE('## SE SELECCIONA LA APP DE ID '|| APP_id);

    --CONSULTA LAS SUCURSALES APLICABLES PARA ESA APP
    OPEN empresas_elegibles(app_id,rand_usuario_id);

    dbms_output.PUT_LINE('## SE OBTIENEN LOS CONTRATOS QUE APLIQUEN DE LA APP ' || app_id);
    dbms_output.PUT_LINE('## SE OBTIENEN LAS EMPRESAS DE LOS CONTRATOS');
    FETCH empresas_elegibles INTO fk_pedidos_sucursal;

    --verifica si existe
    IF empresas_elegibles%FOUND THEN

        SELECT * INTO direccion_usuario
        FROM direcciones
        WHERE id_usuario = rand_usuario_id
        ORDER BY dbms_random.VALUE()
        FETCH FIRST ROW ONLY;

        LOOP
        EXIT WHEN empresas_elegibles%NOTFOUND;
        dbms_output.PUT_LINE('## SE VERIFICA SI LA SUCURSAL MAS CERCANA DE LA EMPRESA ' ||
                            fk_pedidos_sucursal.id_empresa ||
                             ' PUEDE ATENDER EL PEDIDO CON LAS UNIDADES DISPONIBLES DE LA APP');

        id_suc := sucursal_factible(app_id,fk_pedidos_sucursal.id_empresa,direccion_usuario);

        --dbms_output.PUT_LINE('DEBUG '|| id_suc);
        EXIT WHEN id_suc > 0;

        FETCH empresas_elegibles INTO fk_pedidos_sucursal;
        END LOOP;

        IF id_suc > 0 THEN
            dbms_output.PUT_LINE('## SE REGISTRA EL PEDIDO');
            crear_pedido_aleatorio(app_id,
                fk_pedidos_sucursal.id_plan,
                fk_pedidos_sucursal.id_empresa,
                fk_pedidos_sucursal.id_contrato,
                direccion_usuario.id_estado,
                direccion_usuario.id_municipio,
                direccion_usuario.id_zona,
                rand_usuario_id,
                direccion_usuario.id,
                id_suc
                );
        ELSE
            dbms_output.PUT_LINE('NO SE OBTUVO SUCURSAL');

        END IF;

    ELSE
        dbms_output.PUT_LINE('### LA APLICACIÓN NO PRESENTA SERVICIOS O SUCURSALES DISPONIBLES');
    END IF;

    <<fin>>
    NULL;
END;

-- FIN PEDIDOS

-- INICIO DESPACHO

CREATE OR REPLACE FUNCTION unidad_disponible(unidad_id unidades_de_transporte.id%TYPE)
RETURN BOOLEAN
IS
    res NUMBER;
    BEGIN

        SELECT COUNT(1)
        INTO res
        FROM rutas r
        WHERE
              r.id_unidad = unidad_id
            AND cancelado IS NULL
            AND proposito IN ('PEDIDO','ENVIO');

        RETURN (res <= 0);

        EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN TRUE;
    END;

CREATE OR REPLACE PROCEDURE simular_accidente(
    unidad_id unidades_de_transporte.id%TYPE,
    in_pedido pedidos%ROWTYPE,
    nuevo_estado unidades_de_transporte.estado%TYPE,
    ruta_id rutas.id%TYPE,
    ruta_origen rutas.origen%TYPE,
    rapidez tipos_de_unidades.velocidad_media%TYPE
)
IS
    ruta rutas%ROWTYPE;
    nueva_ubi ubicacion;
    nuevo_pedido pedidos.tracking%TYPE;

    testo NUMBER(8,3);
    a DATE;
    b DATE;
BEGIN


    IF nuevo_estado = 'DESCONTINUADA' THEN
        --dbms_output.PUT_LINE('### LA UNIDAD ' || unidad_id || ' HA SUFRIDO UN ACCIDENTE QUE REQUEIRE DESCONTINUARLA');

        UPDATE unidades_de_transporte SET estado = 'DESCONTINUADA'
        WHERE id = unidad_id;
    ELSE
        --dbms_output.PUT_LINE('### LA UNIDAD ' || unidad_id ||' HA SUFRIDO UN ACCIDENTE POR LO TANTO DEBE SER REPARADA');
        UPDATE unidades_de_transporte SET estado = 'REPARACION'
        WHERE id = unidad_id;
    END IF;

    a := SIM_DATE();
    b := ruta_origen.actualizado;
    testo := (a-b)*24;

    nueva_ubi := ubicacion.OBTENER_POSICION(ruta.destino,ruta.origen,
        rapidez,  testo);

    UPDATE rutas r SET r.destino = nueva_ubi
    WHERE ruta.id = ruta_id;

    IF nuevo_estado = 'DESCONTINUADA' THEN

        dbms_output.PUT_LINE('## LA UNIDAD HA DAÑADO EL PEDIDO ' ||
                             'SE HA NOTIFICADO A LA SUCURSAL PARA LA NUEVA ELABORACION DEL MISMO');

        UPDATE pedidos p SET p.cancelado = cancelacion(SIM_DATE(),'EL PEDIDO FUE DESTRUIDO')
        WHERE p.tracking = in_pedido.tracking;

        INSERT INTO pedidos p VALUES (
                                    in_pedido.id_app,
                                    in_pedido.id_plan,
                                    in_pedido.id_empresa,
                                    in_pedido.id_contrato,
                                    DEFAULT,
                                    in_pedido.id_estado,
                                    in_pedido.id_municipio,
                                    in_pedido.id_zona,
                                    in_pedido.id_usuario,
                                    in_pedido.id_direccion,
                                    in_pedido.duracion,
                                    in_pedido.total,
                                    NULL,
                                    NULL,
                                    in_pedido.tracking
                                   )
        RETURNING tracking INTO nuevo_pedido;

        UPDATE detalles SET id_tracking = nuevo_pedido
        WHERE id_tracking = in_pedido.tracking;

    ELSE
        dbms_output.PUT_LINE('## LA UNIDAD HA ACTUALIZADO SU UBICACION PARA QUE OTRA PUEDA FINALIZAR EL PEDIDO');
    END IF;

END;

CREATE OR REPLACE FUNCTION crear_ubicacion( ubi_ref ubicacion)
RETURN ubicacion
IS
BEGIN
    RETURN ubicacion(ubi_ref.latitud,ubi_ref.longitud,SIM_DATE());
END;

CREATE OR REPLACE PROCEDURE modulo_despacho
IS

    --CURSOR SI DE LAS UNIDADES QUE PUEDEN REALIZAR EL PEDIDO (APP,DIR,SUCURSAL)
    CURSOR unidades_permitidas(in_app_id aplicaciones_delivery.id%TYPE,
        in_sucursal sucursales%ROWTYPE,
        in_direccion direcciones%ROWTYPE
        )
    IS
    SELECT udt.id, udt.id_garaje, tdu.distancia_operativa, tdu.velocidad_media, tdu.cantidad_pedidos,
           g.ubicacion as ubicacion_garaje
    FROM garajes g
    INNER JOIN unidades_de_transporte udt ON g.id_app = udt.id_app AND g.id = udt.id_garaje
    INNER JOIN tipos_de_unidades tdu ON tdu.id = udt.id_tipo
    WHERE g.id_app = in_app_id --APP
    AND g.id_estado = in_direccion.id_estado --ESTADO
    AND udt.estado = 'OPERATIVA'
    AND (
        (g.id_zona = in_sucursal.id_zona
             AND
         g.id_zona = in_direccion.id_zona) --ESTAN LOS 3 EN LA MISMA ZONA POR ENDE TODAS PUEDEN ENVIAR
        OR
        (tdu.distancia_operativa IN('MUNICIPIO','ESTADO')
             AND (g.id_municipio = in_sucursal.id_municipio
                      OR
                  g.id_municipio = in_direccion.id_municipio)) --UNO SE ENCUENTRA EN MUNICIPIO DISTITNO
        OR
        (tdu.distancia_operativa = 'ESTADO'
             AND g.id_estado = in_sucursal.id_estado
             AND g.id_estado = in_direccion.id_estado) -- PUEDE ENTREGAR EN EL ESTADO
        )
        ORDER BY tdu.distancia_operativa DESC
        ;

    CURSOR rutas_pedido(pedido_id pedidos.tracking%TYPE)
        IS
        SELECT *
        FROM rutas
        WHERE id_traking = pedido_id
        AND proposito = 'ENVIO'
        AND cancelado IS NOT NULL
        ORDER BY id DESC
        FETCH FIRST ROW ONLY;

    CURSOR pedidos_sucursal(capacidad tipos_de_unidades.cantidad_pedidos%TYPE, sucursal_id sucursales.id%TYPE)
        IS
        SELECT p.*, d4.ubicacion FROM pedidos p,
                (
                    SELECT d.id_tracking, d.id_sucursal, d.id_empresa
                    FROM detalles d
                    WHERE d.id_sucursal = sucursal_id
                    GROUP BY d.id_tracking, d.id_sucursal, d.id_empresa
                ) s,
                direcciones d4
        WHERE p.tracking = s.id_tracking --EQUI JOIN
          AND d4.id = p.id_direccion
          AND p.duracion.fecha_fin IS NULL
          AND p.cancelado IS NULL
          AND p.duracion.fecha_inicio > (SIM_DATE() - (
              SELECT MAX(NVL(p2.tiempo_de_preparacion,0))/24/60
                FROM productos p2
                WHERE p2.id_empresa = s.id_empresa
            ))
              AND 0 = (
                      SELECT COUNT(1)
                      FROM rutas r
                      WHERE r.proposito = 'PEDIDO'
                        AND r.id_traking = p.tracking
                        AND r.cancelado IS NOT NULL
                    ) --SIN RUTAS EN CAMINO O CANCELADAS
        ORDER BY p.duracion.fecha_inicio
        FETCH FIRST capacidad ROWS ONLY;

    pedido_sel pedidos%ROWTYPE;
    preparacion NUMBER;

    sucursal_sel sucursales%ROWTYPE;
    direccion_sel direcciones%ROWTYPE;


    ruta_actual rutas%ROWTYPE;

    ruta_id_actual rutas.id%TYPE;
    ruta_origen_actual rutas.origen%TYPE;

    unidad_trnsp unidades_permitidas%ROWTYPE;

    TYPE pedido_ruta IS RECORD (
        pedido pedidos_sucursal%ROWTYPE,
        ruta rutas.id%TYPE
    );

    TYPE lote_pedido IS TABLE OF pedido_ruta;
    maleta lote_pedido := lote_pedido();

    pedido_aux pedidos%ROWTYPE;
    pedidos_enviados NUMBER := 1;

BEGIN
    dbms_output.PUT_LINE('# MÓDULO DE DESPACHO');

    --selecciona el pedido mas antigo sin finalizar
    --Y SIN RUTAS CANCELADAS O QUE NO SEA RETORNO
    SELECT *
    INTO pedido_sel
    FROM pedidos p
    WHERE p.duracion.fecha_fin IS NULL
    AND p.cancelado IS NULL
    ORDER BY p.duracion.fecha_inicio
    FETCH FIRST ROW ONLY;

    dbms_output.PUT_LINE('## SE OBTIENE EL PEDIDO DE TRACKING '|| pedido_sel.tracking);

    --TODO CANCELAR EL PEDIDO SI HA PASADO MUCHO TIEMPO (?)

    --veririficar si esta listo (pedido)
    SELECT MAX(NVL(p2.tiempo_de_preparacion,0))/24/60
    INTO preparacion
    FROM pedidos p
    INNER JOIN detalles d ON p.tracking = d.id_tracking
    INNER JOIN productos p2 ON d.id_empresa = p2.id_empresa
    WHERE p.tracking = pedido_sel.tracking;

    dbms_output.PUT_LINE('## SE VERIFICA SI EL PEDIDO YA FUE ELEBORADO');

    IF pedido_sel.duracion.fecha_inicio + preparacion > SIM_DATE() THEN
       dbms_output.PUT_LINE('## EL PEDIDO NO HA SIDO ELABORADO');
       GOTO fin;
    END IF;

--    IF pedido_sel.duracion.fecha_inicio + preparacion <= SIM_DATE() THEN

        SELECT d3.*
        INTO direccion_sel FROM sucursales s
        INNER JOIN detalles d2 ON d2.id_tracking = pedido_sel.tracking
        INNER JOIN direcciones d3 ON d3.id = pedido_sel.id_direccion
        WHERE s.id = d2.id_sucursal
        FETCH FIRST ROW ONLY;

        SELECT s.*
        INTO sucursal_sel FROM sucursales s
        INNER JOIN detalles d2 ON d2.id_tracking = pedido_sel.tracking
        INNER JOIN direcciones d3 ON d3.id = pedido_sel.id_direccion
        WHERE s.id = d2.id_sucursal
        FETCH FIRST ROW ONLY;

        preparacion := 24;
        dbms_output.PUT_LINE('## SE CONSULTAN LAS UNIDADES QUE PUEDEN DESPACHAR EL PEDIDO');


        FOR l_unidad IN unidades_permitidas(pedido_sel.id_app
            ,sucursal_sel
            ,direccion_sel)
        LOOP
            unidad_trnsp := l_unidad;
            --dbms_output.PUT_LINE('AMAAA');
            IF unidad_disponible(l_unidad.id)
                   AND preparacion > ubicacion.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(
                    l_unidad.ubicacion_garaje,sucursal_sel.ubicacion,l_unidad.velocidad_media)
                    +
                    ubicacion.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(
                    sucursal_sel.ubicacion,direccion_sel.ubicacion,l_unidad.velocidad_media)
                THEN
                --dbms_output.PUT_LINE('AMAAA asignadaa');
                unidad_trnsp := l_unidad;
                preparacion := ubicacion.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(
                    l_unidad.ubicacion_garaje,sucursal_sel.ubicacion,l_unidad.velocidad_media)
                    +
                    ubicacion.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(
                    sucursal_sel.ubicacion,direccion_sel.ubicacion,l_unidad.velocidad_media);
            END IF;
        END LOOP;

        IF (unidad_trnsp.id IS NULL ) THEN
            --CANCELAR PEDIDO
            dbms_output.PUT_LINE('## LA APLICACION YA NO PUEDE REALIZAR ENVÍOS POR LO TANTO DEBERÁ SER CANCELADO');
            UPDATE pedidos p SET p.cancelado = cancelacion(SIM_DATE(),'NO HAY UNIDADES QUE PUEDAN COMPLETAR EL PEDIDO')
            WHERE p.tracking = pedido_sel.tracking;
            GOTO fin;
        ELSIF NOT unidad_disponible(unidad_trnsp.id) THEN
            dbms_output.PUT_LINE('## LAS UNIDADES SE ENCUENTRAN REALIZANDO PEDIDOS, EL PEDIDO NO PUEDE SER ATENDIDO');
            GOTO fin;
        END IF;
--        ELSE
        --
        dbms_output.PUT_LINE('## SE HA ASIGNADO LA UNIDAD DE TRANSPORTE ' || unidad_trnsp.id);
/*
        --RELEVO
        FOR l_ruta IN rutas_pedido(pedido_sel.tracking)
        LOOP
            dbms_output.PUT_LINE('## LA UNIDAD VA A RETOMAR EL PEDIDO DE LA UNIDAD '|| l_ruta.id_unidad);

            --IR A LA ULTIMA UBICACION
            INSERT INTO rutas VALUES (pedido_sel.id_app,unidad_trnsp.id_garaje,unidad_trnsp.id,
                                      pedido_sel.tracking,DEFAULT,
                                      CREAR_UBICACION(unidad_trnsp.ubicacion_garaje),
                                      CREAR_UBICACION(l_ruta.destino),'PEDIDO',NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            --ACCIDENTE
            IF dbms_random.VALUE(0,1) < 0.1 THEN
                UPDATE unidades_de_transporte SET estado = 'DESCONTINUADA'
                WHERE id = unidad_trnsp.id;
                dbms_output.PUT_LINE('### LA UNIDAD HA SUFRIDO UN ACCIDENTE GRAVE NO PUEDE RETOMAR EL PEDIDO');
                GOTO fin;
            ELSIF dbms_random.VALUE(0,1) < 0.1 THEN
                UPDATE unidades_de_transporte SET estado = 'REPARACION'
                WHERE id = unidad_trnsp.id;
                dbms_output.PUT_LINE('### LA UNIDAD HA SUFRIDO UN ACCIDENTE MENOR NO PUEDE RETOMAR EL PEDIDO');
                GOTO fin;
            END IF;

            INSERT INTO rutas VALUES (pedido_sel.id_app,l_ruta.id_garaje,l_ruta.id_unidad,
                                      pedido_sel.tracking,DEFAULT,
                                      CREAR_UBICACION(unidad_trnsp.ubicacion_garaje),
                                      CREAR_UBICACION(l_ruta.destino),'PEDIDO',NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            INSERT INTO rutas VALUES (pedido_sel.id_app,l_ruta.id_garaje,l_ruta.id_unidad,
                                      pedido_sel.tracking,DEFAULT,CREAR_UBICACION(l_ruta.destino),CREAR_UBICACION(l_ruta.origen),'RETORNO',NULL);

            INSERT INTO rutas VALUES (pedido_sel.id_app,unidad_trnsp.id_garaje,unidad_trnsp.id,
                                      pedido_sel.tracking,DEFAULT,CREAR_UBICACION(l_ruta.destino),CREAR_UBICACION(direccion_sel.ubicacion),'ENVIO',NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            dbms_output.PUT_LINE('## LA UNIDAD HA RETOMADO EL PEDIDO Y SE DIRIGE AL DESTINO');
            --ACCIDENTE
            IF dbms_random.VALUE(0,1) > 0.5 THEN

                IF dbms_random.VALUE(0,1) > 0.5 THEN
                simular_accidente(unidad_trnsp.id,pedido_sel,'REPARACION', ruta_id_actual, ruta_origen_actual,unidad_trnsp.velocidad_media);
                ELSE
                simular_accidente(unidad_trnsp.id,pedido_sel,'DESCONTINUADA', ruta_id_actual, ruta_origen_actual,unidad_trnsp.velocidad_media);
                END IF;

                GOTO fin;
            END IF;

            dbms_output.PUT_LINE('## LA UNIDAD HA ENTREGADO EL PEDIDO');
            UPDATE pedidos p SET p.valoracion = FLOOR(dbms_random.value(3,5)),
                               p.duracion = rango_tiempo(p.duracion.fecha_inicio,SIM_DATE())
            WHERE tracking = pedido_sel.tracking;

            dbms_output.PUT_LINE('## LA UNIDAD SE REGRESA A SU GARAJE');
            INSERT INTO rutas VALUES (pedido_sel.id_app,unidad_trnsp.id_garaje,unidad_trnsp.id,
                                      pedido_sel.tracking,DEFAULT,CREAR_UBICACION(direccion_sel.ubicacion),CREAR_UBICACION(unidad_trnsp.ubicacion_garaje),'RETORNO',NULL);

            GOTO fin;
        END LOOP;*/
        --IR A LA SUCURSAL
        dbms_output.PUT_LINE('## LA UNIDAD SE DIRIGE A RETIRAR EL PEDIDO EN LA SUCURSAL');
        --por cada pedido en la sucursal listo

        --CARGO LOTE
        FOR n_pedido IN pedidos_sucursal(unidad_trnsp.cantidad_pedidos,sucursal_sel.id)
        LOOP
            maleta.extend();
            maleta(maleta.last).pedido := n_pedido;
        END LOOP;

        ruta_origen_actual := CREAR_UBICACION(unidad_trnsp.ubicacion_garaje);

        --CREO RUTA A PEDIDO DE TODOS
        FOR l_ped_rut IN maleta.first..maleta.last
        LOOP
            INSERT INTO rutas VALUES (
                                  maleta(l_ped_rut).pedido.id_app,
                                  unidad_trnsp.id_garaje,
                                  unidad_trnsp.id,
                                  maleta(l_ped_rut).pedido.tracking,
                                  DEFAULT,
                                  ruta_origen_actual,
                                  CREAR_UBICACION(sucursal_sel.ubicacion),
                                  'PEDIDO',
                                  NULL
                                )
            RETURNING id INTO maleta(l_ped_rut).ruta;
        END LOOP;

/*
        --ACCIDENTE
        IF dbms_random.VALUE(0,1) < 0.1 THEN
                UPDATE unidades_de_transporte SET estado = 'DESCONTINUADA'
                WHERE id = unidad_trnsp.id;
                dbms_output.PUT_LINE('### LA UNIDAD HA SUFRIDO UN ACCIDENTE NO SE PUEDE ATENDER EL PEDIDO POR ESTA UNIDAD');
                GOTO fin;
        ELSIF dbms_random.VALUE(0,1) < 0.1 THEN
                UPDATE unidades_de_transporte SET estado = 'REPARACION'
                WHERE id = unidad_trnsp.id;
                dbms_output.PUT_LINE('### LA UNIDAD HA SUFRIDO UN ACCIDENTE MENOR NO SE PUEDE ATENDER EL PEDIDO POR ESTA UNIDAD');
                GOTO fin;
        END IF;*/

        dbms_output.PUT_LINE('## LA UNIDAD SE DIRIGE A ENVIAR  ' || maleta.count || ' PEDIDO(S)');
        ruta_origen_actual := CREAR_UBICACION(sucursal_sel.ubicacion);
        <<despacho_a_enesimo_destino>>
        IF (pedidos_enviados > 1) THEN
            ruta_origen_actual := CREAR_UBICACION(maleta(pedidos_enviados - 1).pedido.ubicacion);
        END IF;
        --AQUI HACE
        FOR l_ped_rut IN pedidos_enviados..maleta.last
        LOOP
            INSERT INTO rutas VALUES (
                                  maleta(l_ped_rut).pedido.id_app,
                                  unidad_trnsp.id_garaje,
                                  unidad_trnsp.id,
                                  maleta(l_ped_rut).pedido.tracking,
                                  DEFAULT,
                                  ruta_origen_actual,
                                  CREAR_UBICACION(maleta(pedidos_enviados).pedido.ubicacion),
                                  'ENVIO',
                                  NULL
                                )
            RETURNING id INTO maleta(l_ped_rut).ruta;
        END LOOP;

        --ACCIDENTE
        IF dbms_random.VALUE(0,1) > 0.5 THEN
            IF dbms_random.VALUE(0,1) > 0.5 THEN
               FOR l_ped_rut IN pedidos_enviados..maleta.last
                LOOP

                simular_accidente(
                    unidad_trnsp.id,
                    pedido_sel,
                    'REPARACION',
                    maleta(l_ped_rut).ruta,
                    ruta_origen_actual,
                    unidad_trnsp.velocidad_media);
                END LOOP;
            ELSE
                FOR l_ped_rut IN pedidos_enviados..maleta.last
                LOOP
                    simular_accidente(unidad_trnsp.id,
                    pedido_sel,
                    'DESCONTINUADA',
                    maleta(l_ped_rut).ruta,
                    ruta_origen_actual,
                    unidad_trnsp.velocidad_media);
                END LOOP;
            END IF;
            GOTO fin;
        END IF;

        dbms_output.PUT_LINE('## LA UNIDAD HA ENTREGADO EL PEDIDO ' || pedidos_enviados);
/*        FOR l_ped_rut IN pedidos_enviados..maleta.last
        LOOP
            IF l_ped_rut = pedidos_enviados THEN
               UPDATE pedidos p SET p.valoracion = dbms_random.VALUE(4,5),
                            p.duracion = rango_tiempo(p.duracion.fecha_inicio,SIM_DATE())
                WHERE tracking = maleta(pedidos_enviados).pedido.tracking;
            ELSIF l_ped_rut > pedidos_enviados THEN
                INSERT INTO rutas VALUES (
                                  maleta(l_ped_rut).pedido.id_app,
                                  unidad_trnsp.id_garaje,
                                  unidad_trnsp.id,
                                  maleta(l_ped_rut).pedido.tracking,
                                  DEFAULT,
                                  CREAR_UBICACION(maleta(pedidos_enviados).pedido.ubicacion),
                                  CREAR_UBICACION(maleta(pedidos_enviados+1).pedido.ubicacion),
                                  'ENVIO',
                                  NULL
                                )
                RETURNING id INTO maleta(l_ped_rut).ruta;
            END IF;

        END LOOP;*/

        UPDATE pedidos p SET p.valoracion = dbms_random.VALUE(4,5),
                            p.duracion = rango_tiempo(p.duracion.fecha_inicio,SIM_DATE())
        WHERE tracking = maleta(pedidos_enviados).pedido.tracking;

        IF (pedidos_enviados < maleta.count) THEN
            pedidos_enviados := pedidos_enviados + 1;
            GOTO despacho_a_enesimo_destino;
        ELSE
            dbms_output.PUT_LINE('## LA UNIDAD SE REGRESA A SU GARAJE');
            INSERT INTO rutas VALUES (pedido_sel.id_app,unidad_trnsp.id_garaje,unidad_trnsp.id,pedido_sel.tracking,
                                  DEFAULT,direccion_sel.ubicacion,unidad_trnsp.ubicacion_garaje,'RETORNO',NULL);
        END IF;

 --       END IF;

--    END IF;

    <<fin>>
    NULL;

/*    EXCEPTION
        WHEN OTHERS THEN dbms_output.PUT_LINE('NO HAY PEDIDOS QUE ATENDER ?');*/

END;


-- FIN DESPACHO

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

