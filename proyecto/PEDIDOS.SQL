CREATE OR REPLACE FUNCTION elegir_usuario_aleatorio RETURN sys_refcursor
IS
    rf_cur   sys_refcursor;
BEGIN
    DBMS_OUTPUT.PUT_LINE('## SOLICITAMOS LOS USUARIOS DISPONIBLES ORDENADOS ALEATORIAMENTE');
    OPEN rf_cur FOR SELECT * FROM USUARIOS ORDER BY DBMS_RANDOM.VALUE();
    RETURN rf_cur;
END;

CREATE OR REPLACE FUNCTION elegir_ubicacion_usuario(p_usuario INTEGER) RETURN INTEGER
IS
    dir_usuario DIRECCIONES%ROWTYPE;
    z_id INTEGER;
    e_nombre VARCHAR2(80);
    m_nombre VARCHAR(80);
    z_nombre VARCHAR(80);
BEGIN
    DBMS_OUTPUT.PUT_LINE('## SOLICITAMOS LA DIRECCIÓN DEL USUARIO ALEATORIAMENTE');
    SELECT * INTO dir_usuario FROM DIRECCIONES DIR WHERE p_usuario = DIR.id_usuario ORDER BY DBMS_RANDOM.VALUE() FETCH FIRST ROW ONLY;
    z_id := dir_usuario.id_zona;
    SELECT
        E.nombre, M.nombre, Z.nombre
    INTO
        e_nombre, m_nombre, z_nombre
    FROM
        ZONAS Z
    INNER JOIN
        MUNICIPIOS M ON M.id = Z.id_municipio
    INNER JOIN
        ESTADOS E ON E.id = Z.id_estado
    WHERE
        Z.id = z_id;
    DBMS_OUTPUT.PUT_LINE('### LA DIRECCIÓN PARA EL ENVIO SE ENCUENTRA EN ' || e_nombre || ', ' || m_nombre || ', ' || z_nombre);
    DBMS_OUTPUT.PUT_LINE('###: REFERENCIA ' || dir_usuario.descripcion);
    RETURN dir_usuario.ID;
END;

CREATE OR REPLACE FUNCTION condicion_proximidad(
d_id INTEGER,
s_id INTEGER
) RETURN NUMBER
IS
    puntuacion NUMBER;
    dire DIRECCIONES%ROWTYPE;
    sucu SUCURSALES%ROWTYPE;
    e_n VARCHAR2(80);
    m_n VARCHAR2(80);
    z_n VARCHAR2(80);
BEGIN
    SELECT S.* INTO sucu FROM SUCURSALES S WHERE S.id = s_id;
    SELECT DIR.* INTO dire FROM DIRECCIONES DIR WHERE DIR.id = d_id;
    SELECT Z.NOMBRE, M.NOMBRE, E.NOMBRE INTO z_n, m_n, e_n FROM ZONAS Z INNER JOIN MUNICIPIOS M on Z.ID_ESTADO = M.ID_ESTADO and Z.ID_MUNICIPIO = M.ID INNER JOIN ESTADOS E on E.ID = M.ID_ESTADO WHERE Z.id = dire.ID_ZONA;
    puntuacion := 1;
    IF (sucu.ID_ESTADO != dire.ID_ESTADO) THEN
        DBMS_OUTPUT.PUT_LINE('ALGO ANDA MALLLLLLLLLLLLLLLLLLLLLLLLLL ' || sucu.ID_ESTADO  || ' ' || dire.ID_ESTADO);
    END IF;
    IF (sucu.ID_MUNICIPIO = dire.ID_MUNICIPIO) THEN
        puntuacion := puntuacion + 1;
    END IF;
    IF (sucu.ID_ZONA = dire.ID_ZONA) THEN
        puntuacion := puntuacion + 1;
    END IF;
    puntuacion := puntuacion + 1/(UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(UBICACION(sucu.UBICACION.latitud, sucu.UBICACION.longitud, SIM_DATE()),UBICACION(dire.UBICACION.latitud, dire.UBICACION.longitud, SIM_DATE()), 40)*60);
    DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL '|| s_id ||' OBTUVO UN PUNTAJE DE ' || TO_CHAR(puntuacion, '9.99999') || ' UBICADA EN ' || e_n || ', ' || m_n || ', ' || z_n);
    RETURN puntuacion;
END;

CREATE OR REPLACE FUNCTION elegir_sucursal_pedido(u_id INTEGER, dir_u_id INTEGER, app_ID IN OUT INTEGER, plan_ID IN OUT INTEGER, contra_ID IN OUT INTEGER) RETURN INTEGER
IS
    sucur_cur SYS_REFCURSOR;
    direccion DIRECCIONES%ROWTYPE;
    d DATE;

    APPID INTEGER;
    PLANID INTEGER;
    CONTRATOID INTEGER;
    EMPRESAID INTEGER;
    SUCURSALID INTEGER;
    ESTADOID INTEGER;
    MUNICIPIOID INTEGER;
    ZONAID INTEGER;
    NOMBRE_EMPRESA VARCHAR2(80);
    PRODUCTOS INTEGER;

BEGIN
    d := SIM_DATE();
    SELECT D.* INTO direccion FROM DIRECCIONES D WHERE D.ID = dir_u_id;
    OPEN sucur_cur FOR SELECT
        AP.id APP,
        AP.APP.NOMBRE NOMBRE_APP,
        PDS.ID PLAN,
        C2.ID CONTRATO,
        C2.ID_EMPRESA EMPRESA,
        S.ID SUCURSAL,
        S.ID_ESTADO ESTADO,
        S.ID_MUNICIPIO MUNICIPIO,
        S.ID_ZONA ZONA
    FROM
        APLICACIONES_DELIVERY AP
    INNER JOIN
        PLANES_DE_SERVICIO PDS ON AP.ID = PDS.ID_APP AND (PDS.DURACION.fecha_fin >= d OR  PDS.DURACION.fecha_fin IS NULL)AND PDS.CANCELADO IS NULL
    INNER JOIN
        UBICACIONES_APLICABLES UAP ON UAP.ID_PLAN = PDS.ID AND UAP.ID_APP = PDS.ID_APP AND UAP.ID_ESTADO = direccion.ID_ESTADO
    INNER JOIN
        CONTRATOS C2 ON PDS.ID_APP = C2.ID_APP and PDS.ID = C2.ID_PLAN AND (C2.DURACION.fecha_fin >= d OR C2.DURACION.fecha_fin IS NULL) AND C2.CANCELADO IS NULL
    INNER JOIN
        SUCURSALES S ON C2.ID_EMPRESA = S.ID_EMPRESA AND S.ID_ESTADO = direccion.ID_ESTADO
    GROUP BY
        AP.id,
        AP.APP.NOMBRE,
        PDS.ID,
        C2.ID,
        C2.ID_EMPRESA,
        S.ID,
        UAP.ID_ESTADO,
        S.ID_ESTADO,
        S.ID_MUNICIPIO,
        S.ID_ZONA
    ORDER BY
        condicion_proximidad(dir_u_id, S.ID) DESC;
    LOOP
        FETCH sucur_cur INTO
            APPID,
            NOMBRE_EMPRESA,
            PLANID,
            CONTRATOID,
            EMPRESAID,
            SUCURSALID,
            ESTADOID,
            MUNICIPIOID,
            ZONAID;
        EXIT WHEN sucur_cur%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE('## SE HA ELEGIDO LA APLICACIÓN (' || APPID || ')' || ' ' || NOMBRE_EMPRESA || ' PLAN (' || PLANID  ||')' || ' CONTRATO (' || CONTRATOID || ')');
            app_ID := APPID;
            plan_ID := PLANID;
            contra_ID := CONTRATOID;
            SELECT E.EMPRESA.NOMBRE INTO NOMBRE_EMPRESA FROM EMPRESAS E WHERE E.id = EMPRESAID;
            DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' ES LA CANDIDATA MÁS CERCANA PARA ENVIAR');
            SELECT SUM(ALM.DISPONIBILIDAD) INTO PRODUCTOS FROM ALMACENES ALM WHERE ALM.ID_EMPRESA = EMPRESAID AND ALM.ID_SUCURSAL = SUCURSALID;
            IF (PRODUCTOS > 0) THEN
                DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' PUEDE HACER EL ENVIO');
                DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' TIENE ' || PRODUCTOS || ' PRODUCTOS DISPONIBLES');
                RETURN SUCURSALID;
            END IF;
            DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' NO PUEDE SER SELECIONADA PARA EL ENVIO');
    END LOOP;
    app_ID := 0;
    plan_ID := 0;
    contra_ID := 0;
    RETURN NULL;
END;

CREATE OR REPLACE PROCEDURE nuevo_pedido(dir_u_id INTEGER, app_id INTEGER, plan_id INTEGER, contra_id INTEGER, sucur_id INTEGER)
IS
    dir DIRECCIONES%ROWTYPE;
    usuario USUARIOS%ROWTYPE;
    sucursal SUCURSALES%ROWTYPE;
    aplicacion APLICACIONES_DELIVERY%ROWTYPE;
    empresa EMPRESAS%ROWTYPE;
    evento EVENTOS%ROWTYPE;
    producto ALMACENES%ROWTYPE;
    precio NUMBER(8,2);
    a_pagar NUMBER(5,2);
    t INTEGER;
    prod_cur SYS_REFCURSOR;
    c INTEGER;
    cantidad_productos INTEGER;
    total_c NUMBER(15,2);
    tiempo INTEGER;
    tiempo_max INTEGER;
BEGIN
    total_c := 0;
    tiempo_max := 0;
    cantidad_productos := TRUNC(DBMS_RANDOM.VALUE(3,5));
    SELECT D.* INTO dir FROM DIRECCIONES D WHERE D.ID = dir_u_id;
    SELECT U.* INTO usuario FROM USUARIOS U WHERE U.id = dir.ID_USUARIO;
    SELECT S.* INTO sucursal FROM SUCURSALES S WHERE S.ID = sucur_id;
    SELECT A.* INTO aplicacion FROM APLICACIONES_DELIVERY A WHERE A.ID = app_id;
    SELECT E.* INTO empresa FROM EMPRESAS E WHERE E.ID = sucursal.ID_EMPRESA;
    --SELECT EV.* INTO evento FROM EVENTOS EV WHERE EV.ID_SUCURSAL = sucursal.ID_EMPRESA AND EV.DURACION.fecha_inicio >= SIM_DATE() AND EV.DURACION.fecha_fin;
    IF (evento.ID IS NULL) THEN
        DBMS_OUTPUT.PUT_LINE('NO HAY PROMOCIONES O DESCUENTOS PARA LA SUCURSAL (' || sucursal.ID || ')');
        a_pagar := 100;
    ELSE
        DBMS_OUTPUT.PUT_LINE('PARA TODOS LOS PRODUCTOS DE LA SUCURSAL (' || sucursal.ID || ') SE APLICA UN DESCUENTO DE ' || evento.PORCENTAJE_DESCUENTO || '%');
        a_pagar := 100 - evento.PORCENTAJE_DESCUENTO;
    END IF;

    INSERT INTO PEDIDOS VALUES
                        (app_id,
                        plan_id,
                        empresa.ID,
                        contra_id,
                        DEFAULT,
                        dir.ID_ESTADO,
                        dir.ID_MUNICIPIO,
                        dir.ID_ZONA,
                        dir.ID_USUARIO,
                        dir.ID,
                        RANGO_TIEMPO(SIM_DATE()),
                        0,
                        NULL,
                        NULL,
                        NULL
                        ) RETURNING TRACKING INTO t;

    OPEN prod_cur FOR SELECT ALM.* FROM ALMACENES ALM WHERE ALM.ID_SUCURSAL = sucur_id AND ALM.DISPONIBILIDAD > 0 ORDER BY DBMS_RANDOM.VALUE();
    LOOP
        FETCH prod_cur INTO producto;
        EXIT WHEN prod_cur%NOTFOUND OR cantidad_productos <= 0;
        SELECT p.PRECIO, p.TIEMPO_DE_PREPARACION INTO precio, tiempo FROM PRODUCTOS P WHERE P.ID = producto.ID_PRODUCTO;
        precio := precio*a_pagar/100;
        IF precio < 71 THEN
            c := DBMS_RANDOM.VALUE(1, 5);
        ELSE
            c := DBMS_RANDOM.VALUE(1, 2);
        END IF;
        IF c > producto.DISPONIBILIDAD THEN
            c := producto.DISPONIBILIDAD;
        END IF;
        IF tiempo > tiempo_max THEN
            tiempo_max := tiempo;
        END IF;
        INSERT INTO DETALLES VALUES (producto.ID_EMPRESA, producto.ID_SUCURSAL, producto.ID_PRODUCTO, t, DEFAULT, precio, c);
        UPDATE ALMACENES ALM SET ALM.DISPONIBILIDAD = producto.DISPONIBILIDAD - c WHERE ALM.ID_PRODUCTO = producto.ID_PRODUCTO AND producto.ID_SUCURSAL = ALM.ID_SUCURSAL;

        total_c := total_c + precio*c;
        cantidad_productos := cantidad_productos - 1;
    END LOOP;
    UPDATE PEDIDOS PD SET PD.TOTAL = total_c, PD.DURACION = RANGO_TIEMPO(SIM_DATE() + tiempo_max/60/24) WHERE PD.TRACKING = t;
    DBMS_OUTPUT.PUT_LINE('## SE HA GENERADO UN NUEVO PEDIDO PARA ' || usuario.PRIMER_NOMBRE || ' ' || usuario.PRIMER_APELLIDO || ' ');
    DBMS_OUTPUT.PUT_LINE('### EN LA SUCURSAL (' || sucursal.ID || ') DE LA EMPRESA ' || empresa.EMPRESA.nombre || ' CON LA APP '|| aplicacion.app.nombre);
    DBMS_OUTPUT.PUT_LINE('### PEDIDO CON EL ID (' || t || ') POR UN TOTAL DE $' || total_c || ' EL ' || SIM_DATE());
END;

CREATE OR REPLACE PROCEDURE generar_pedido(p_cantidad_de_pedidos NUMBER)
IS
    usuario USUARIOS%ROWTYPE;
    dir_u_id INTEGER;
    sucur INTEGER;
    app_id INTEGER;
    plan_id INTEGER;
    contra_id INTEGER;
    user_cur SYS_REFCURSOR;

    -- Contadores
    c_cantidad_de_pedidos INTEGER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('# SE INICIA EL MÓDULO DE GENERACIÓN DE PEDIDO');
    user_cur := elegir_usuario_aleatorio();
    c_cantidad_de_pedidos := p_cantidad_de_pedidos;
    LOOP
        FETCH user_cur INTO usuario;
        EXIT WHEN user_cur%NOTFOUND OR c_cantidad_de_pedidos <= 0;
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('## SE HA RECIBIDO UNA SOLICITUD DE ' || usuario.primer_nombre || ' ' || usuario.primer_apellido || ' PARA HACER UN PEDIDO');
        dir_u_id := elegir_ubicacion_usuario(usuario.id);
        sucur := elegir_sucursal_pedido(usuario.ID, dir_u_id, app_id, plan_id, contra_id);
        DBMS_OUTPUT.PUT_LINE('## GENERANDO PEDIDO CON LA APP (' || app_id || ') CON EL PLAN (' || plan_id || ') BAJO EL CONTRATO (' || contra_id || ') PARA LA SUCURSUAL (' || sucur || ')');
        nuevo_pedido(dir_u_id, app_id, plan_id, contra_id, sucur);

        c_cantidad_de_pedidos := c_cantidad_de_pedidos - 1;
    END LOOP;
    RETURN;
END;

CALL generar_pedido(10);

SELECT * FROM DIRECCIONES;