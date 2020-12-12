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

CREATE OR REPLACE FUNCTION elegir_sucursal_pedido(u_id INTEGER, dir_u_id INTEGER, app_ID IN OUT INTEGER) RETURN INTEGER
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
            DBMS_OUTPUT.PUT_LINE('SE HA ELEGIDO LA APLICACIÓN (' || APPID || ')' || ' ' || NOMBRE_EMPRESA);
            app_ID := APPID;
            SELECT E.EMPRESA.NOMBRE INTO NOMBRE_EMPRESA FROM EMPRESAS E WHERE E.id = EMPRESAID;
            DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' ES LA CANDIDATA MÁS CERCANA PARA ENVIAR');
            SELECT SUM(ALM.DISPONIBILIDAD) INTO PRODUCTOS FROM ALMACENES ALM WHERE ALM.ID_EMPRESA = EMPRESAID AND ALM.ID_SUCURSAL = SUCURSALID;
            IF (PRODUCTOS > 0) THEN
                DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' HA SIDO SELECIONADA PARA EL ENVIO');
                RETURN SUCURSALID;
            END IF;
            DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' NO PUEDE SER SELECIONADA PARA EL ENVIO');
    END LOOP;
    RETURN NULL;
END;

CREATE OR REPLACE PROCEDURE generar_pedido(p_cantidad_de_pedidos NUMBER)
IS
    usuario USUARIOS%ROWTYPE;
    dir_u_id INTEGER;
    sucur INTEGER;
    app_id INTEGER;
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
        sucur := elegir_sucursal_pedido(usuario.ID, dir_u_id, app_id);
        --DBMS_OUTPUT.PUT_LINE(app_id);

        c_cantidad_de_pedidos := c_cantidad_de_pedidos - 1;
    END LOOP;
    RETURN;
END;

CALL generar_pedido(3);

SELECT * FROM DIRECCIONES;