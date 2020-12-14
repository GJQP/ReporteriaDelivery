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
    SELECT Z.NOMBRE, M.NOMBRE, E.NOMBRE INTO z_n, m_n, e_n FROM ZONAS Z INNER JOIN MUNICIPIOS M on Z.ID_ESTADO = M.ID_ESTADO and Z.ID_MUNICIPIO = M.ID INNER JOIN ESTADOS E on E.ID = M.ID_ESTADO WHERE Z.id = sucu.ID_ZONA;
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
        PLANES_DE_SERVICIO PDS ON AP.ID = PDS.ID_APP AND AP.ID = PDS.ID_APP AND (PDS.DURACION.fecha_fin >= d OR  PDS.DURACION.fecha_fin IS NULL)AND PDS.CANCELADO IS NULL
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
        DBMS_RANDOM.VALUE(), condicion_proximidad(dir_u_id, S.ID) DESC;
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
                DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || SUCURSALID || ') DE ' || NOMBRE_EMPRESA || ' PUEDE TOMAR UN PEDIDO');
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
    DBMS_OUTPUT.PUT_LINE('### PEDIDO CON EL ID (' || t || ') POR UN TOTAL DE $' || total_c || ' EL ' || SIM_DATE() || ' MAS UN TIEMPO DE PREPARACION DE ' || tiempo_max || ' MINUTOS');
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
        IF sucur IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('## GENERANDO PEDIDO CON LA APP (' || app_id || ') CON EL PLAN (' || plan_id || ') BAJO EL CONTRATO (' || contra_id || ') PARA LA SUCURSUAL (' || sucur || ')');
            nuevo_pedido(dir_u_id, app_id, plan_id, contra_id, sucur);
        ELSE
            DBMS_OUTPUT.PUT_LINE('## PARA LA UBICACIÓN ELEGIDA NINGUNA SUCURSAL PUEDE ATENDER EL PEDIDO');
        END IF;
        c_cantidad_de_pedidos := c_cantidad_de_pedidos - 1;
    END LOOP;
    RETURN;
END;

CREATE OR REPLACE FUNCTION numero_de_rutas(tracking NUMBER) RETURN NUMBER
IS
    numero_de_rutas INTEGER;
BEGIN
    SELECT COUNT(RT.ID) INTO numero_de_rutas FROM RUTAS RT WHERE RT.ID_TRAKING = tracking;
    RETURN numero_de_rutas;
END;


CREATE OR REPLACE FUNCTION obtener_pedidos RETURN sys_refcursor
IS
    pedidos_cur SYS_REFCURSOR;
    d DATE;
BEGIN
    d := SIM_DATE();
    DBMS_OUTPUT.PUT_LINE('## SELECIONAMOS TODOS LOS PEDIDOS VIGENTES');
    OPEN pedidos_cur FOR
    SELECT
        PD.*
    FROM
        PEDIDOS PD
    WHERE
        PD.DURACION.fecha_inicio <= SIM_DATE() AND PD.DURACION.fecha_fin IS NULL AND PD.CANCELADO IS NULL
    ORDER BY
        PD.DURACION.fecha_inicio;
    RETURN pedidos_cur;
END;

CREATE OR REPLACE FUNCTION unidad_libre(id_unidad_actual INTEGER) RETURN INTEGER
IS
    veces INTEGER;
    d DATE;
BEGIN
    d := SIM_DATE();
    SELECT
        COUNT(R.ID)
    INTO
        veces
    FROM
        PEDIDOS PD
    INNER JOIN
        RUTAS R on PD.TRACKING = R.ID_TRAKING AND R.CANCELADO IS NULL AND R.PROPOSITO != 'RETORNO' AND R.ID_UNIDAD = id_unidad_actual
    WHERE
        PD.DURACION.fecha_fin IS NULL AND
        PD.CANCELADO IS NULL;
    IF veces = 0 THEN
        RETURN 1;
    END IF;
    RETURN 0;
END;

CREATE OR REPLACE FUNCTION obtener_posicion_unidad(id_uni INTEGER) RETURN UBICACION
IS
    d DATE;
    garaje GARAJES%ROWTYPE;
    ruta RUTAS%ROWTYPE;
    tipo TIPOS_DE_UNIDADES%ROWTYPE;
    rut_cur SYS_REFCURSOR;
    delta NUMBER;
    vel NUMBER;
    ultima_pos UBICACION;
BEGIN
    d := SIM_DATE();
    SELECT G.* INTO garaje
    FROM UNIDADES_DE_TRANSPORTE UDT
    INNER JOIN GARAJES G on G.ID_APP = UDT.ID_APP and G.ID = UDT.ID_GARAJE
    WHERE UDT.ID = id_uni;
    SELECT TDU.VELOCIDAD_MEDIA INTO vel FROM UNIDADES_DE_TRANSPORTE UDT INNER JOIN TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO WHERE UDT.ID = id_uni;

    OPEN rut_cur FOR
    SELECT
        R.*
    FROM
        PEDIDOS PD
    INNER JOIN
        RUTAS R on PD.TRACKING = R.ID_TRAKING AND R.CANCELADO IS NULL AND R.ID_UNIDAD = id_uni
    WHERE
        PD.CANCELADO IS NULL AND PD.DURACION.fecha_fin IS NULL
    ORDER BY
        R.ID;
    LOOP
         FETCH rut_cur INTO ruta;
         EXIT WHEN rut_cur%NOTFOUND;
         IF ruta.PROPOSITO = 'PEDIDO' THEN
            ultima_pos := UBICACION(ruta.ORIGEN.latitud, ruta.ORIGEN.longitud, ruta.ORIGEN.actualizado);
         END IF;
            delta := (d - CAST(ultima_pos.actualizado AS DATE))*24;
            ultima_pos := UBICACION.OBTENER_POSICION(UBICACION(ruta.DESTINO.latitud, ruta.DESTINO.longitud, ruta.DESTINO.actualizado),UBICACION(ultima_pos.latitud, ultima_pos.longitud, ultima_pos.actualizado),40 , delta);
        IF CAST(ultima_pos.actualizado AS DATE) = d THEN
            DBMS_OUTPUT.PUT_LINE('## LA UNIDAD '|| ruta.ID_UNIDAD || ' ESTA FUERA DEL GARAGE');
            RETURN UBICACION(ultima_pos.latitud, ultima_pos.longitud, d);
        ELSIF ruta.PROPOSITO = 'RETORNO' AND CAST(ultima_pos.actualizado AS DATE) < d THEN
            DBMS_OUTPUT.PUT_LINE('## LA UNIDAD '|| ruta.ID_UNIDAD || 'SE ENCUENTRA EN EL GARAGE Y ESTABA REALIZANDO UN ENVIO');
            RETURN UBICACION(garaje.UBICACION.latitud, garaje.UBICACION.longitud, d);
        end if;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('## LA UNIDAD '|| id_uni|| ' SE ENCUENTRA EN EL GARAGE Y NO ESTABA REALIZANDO UN ENVIO');
    RETURN UBICACION(garaje.UBICACION.latitud, garaje.UBICACION.longitud, d);
END;

CREATE OR REPLACE FUNCTION unidad_aplicable_rango(uni INTEGER, id_sucur INTEGER) RETURN INTEGER
IS
    tipo TIPOS_DE_UNIDADES%ROWTYPE;
    sucur SUCURSALES%ROWTYPE;
    gar GARAJES%ROWTYPE;
BEGIN
    SELECT TDU.* INTO tipo FROM UNIDADES_DE_TRANSPORTE UDT INNER JOIN TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO WHERE UDT.ID = uni;
    SELECT S.* INTO sucur FROM SUCURSALES S WHERE S.ID = id_sucur;
    SELECT G.* INTO gar FROM UNIDADES_DE_TRANSPORTE UDT INNER JOIN GARAJES G on G.ID_APP = UDT.ID_APP and G.ID = UDT.ID_GARAJE WHERE UDT.ID = uni;
    IF tipo.DISTANCIA_OPERATIVA = 'ESTADO' AND gar.ID_ESTADO = sucur.ID_ESTADO OR
    tipo.DISTANCIA_OPERATIVA = 'MUNICIPIO' AND gar.ID_MUNICIPIO = sucur.ID_MUNICIPIO OR
    tipo.DISTANCIA_OPERATIVA = 'ZONA' AND gar.ID_ZONA = sucur.ID_ZONA THEN
        RETURN 1;
    END IF;
    RETURN 0;
END;

CREATE OR REPLACE FUNCTION ordenar_por_distancia_sucursal(uni_id INTEGER, lat_sucur NUMBER, lon_sucur NUMBER, act_sucur TIMESTAMP, uni_vel NUMBER) RETURN NUMBER
IS
BEGIN
    RETURN UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(obtener_posicion_unidad(uni_id), UBICACION(lat_sucur, lon_sucur, act_sucur), uni_vel);
END;

CREATE OR REPLACE PROCEDURE elegir_unidad_disponible_proxima(id_sucur INTEGER, id_a INTEGER, id_uni IN OUT INTEGER, id_gar IN OUT INTEGER)
IS
    uni UNIDADES_DE_TRANSPORTE%ROWTYPE;
    sucur SUCURSALES%ROWTYPE;
    uni_cur SYS_REFCURSOR;
BEGIN
    id_uni := NULL;
    id_gar := NULL;
    SELECT S.* INTO sucur FROM SUCURSALES S WHERE S.ID = id_sucur;
         DBMS_OUTPUT.PUT_LINE('## PASA ' || sucur.ID || ' ' || sucur.ID_ESTADO || ' ' || id_a || ' ' || id_uni || ' ' || id_gar);
    OPEN uni_cur FOR
    SELECT
        UDT.*
    FROM
        GARAJES GS
    INNER JOIN
        UNIDADES_DE_TRANSPORTE UDT ON GS.ID_APP = UDT.ID_APP AND GS.ID = UDT.ID_GARAJE AND UDT.ESTADO = 'OPERATIVA'
    INNER JOIN
        TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO
    WHERE
        GS.ID_APP = id_a AND GS.ID_ESTADO = sucur.ID_ESTADO AND 1 = unidad_libre(UDT.ID) AND 1 = unidad_aplicable_rango(UDT.ID, sucur.id)
    ORDER BY
        ordenar_por_distancia_sucursal(UDT.ID, sucur.UBICACION.latitud, sucur.UBICACION.longitud, sucur.UBICACION.actualizado, TDU.VELOCIDAD_MEDIA), TDU.ID;
    LOOP
        FETCH uni_cur INTO uni;
        EXIT WHEN uni_cur%NOTFOUND;
        id_uni := uni.ID;
        id_gar := uni.ID_GARAJE;
    END LOOP;
        DBMS_OUTPUT.PUT_LINE('## PASA');
    RETURN;
END;

CREATE OR REPLACE FUNCTION obtener_pedidos_suscursal(id_sucur INTEGER) RETURN SYS_REFCURSOR
IS
    pedidos_cur SYS_REFCURSOR;
    d DATE;
BEGIN
    d := SIM_DATE();
    DBMS_OUTPUT.PUT_LINE('## SELECIONAMOS TODOS LOS PEDIDOS DE LA SUCURSAL (' || id_sucur || ')');
    OPEN pedidos_cur FOR
    SELECT
        PD.*
    FROM
        PEDIDOS PD
    WHERE
        PD.DURACION.fecha_inicio <= SIM_DATE() AND PD.DURACION.fecha_fin IS NULL AND PD.CANCELADO IS NULL
        AND 0 = numero_de_rutas(PD.TRACKING)
        AND PD.TRACKING IN (SELECT D.ID_TRACKING FROM DETALLES D WHERE D.ID_SUCURSAL = id_sucur GROUP BY D.ID_TRACKING)
    ORDER BY
        PD.DURACION.fecha_inicio;
    --DBMS_OUTPUT.PUT_LINE('asd');
    RETURN pedidos_cur;
END;

CREATE OR REPLACE FUNCTION alcance_unidad_posible(id_unidad INTEGER, id_direc INTEGER) RETURN INTEGER
IS
    uni UNIDADES_DE_TRANSPORTE%ROWTYPE;
    tipo TIPOS_DE_UNIDADES%ROWTYPE;
    gar GARAJES%ROWTYPE;
    direc DIRECCIONES%ROWTYPE;
BEGIN
    SELECT UDT.* INTO uni FROM UNIDADES_DE_TRANSPORTE UDT WHERE UDT.ID = id_unidad;
    SELECT TDU.* INTO tipo FROM TIPOS_DE_UNIDADES TDU WHERE TDU.ID = id_unidad;
    SELECT G.* INTO gar FROM GARAJES G WHERE G.ID = uni.ID_GARAJE;
    SELECT DIR.* INTO direc FROM DIRECCIONES DIR WHERE DIR.ID = id_direc;
    IF tipo.DISTANCIA_OPERATIVA = 'ESTADO' AND gar.ID_ESTADO != direc.ID_ESTADO THEN
        RETURN 0;
    ELSIF tipo.DISTANCIA_OPERATIVA = 'MUNICIPIO' AND gar.ID_MUNICIPIO != direc.ID_MUNICIPIO  THEN
        RETURN 0;
    ELSIF tipo.DISTANCIA_OPERATIVA = 'ZONA' AND gar.ID_MUNICIPIO != direc.ID_ZONA  THEN
        RETURN 0;
    END IF;
    RETURN 1;
END;

CREATE OR REPLACE PROCEDURE crear_rutas(p_tracking NUMBER) IS
    pedido PEDIDOS%ROWTYPE;
    ps PEDIDOS%ROWTYPE;
    id_uni INTEGER;
    unidad UNIDADES_DE_TRANSPORTE%ROWTYPE;
    tipo TIPOS_DE_UNIDADES%ROWTYPE;
    gar GARAJES%ROWTYPE;
    sucur SUCURSALES%ROWTYPE;
    direc DIRECCIONES%ROWTYPE;
    delta DATE;
    beta DATE;
    id_gar INTEGER;
    id_sucur INTEGER;
    ped_cur SYS_REFCURSOR;
    ult_ubi UBICACION;
    uni_ped INTEGER;
BEGIN
    uni_ped := 1;
    SELECT PD.* INTO pedido FROM PEDIDOS PD WHERE PD.TRACKING = p_tracking;
    SELECT D.ID_SUCURSAL INTO id_sucur FROM PEDIDOS PD INNER JOIN DETALLES D on PD.TRACKING = D.ID_TRACKING WHERE PD.TRACKING = pedido.TRACKING GROUP BY D.ID_SUCURSAL;
    DBMS_OUTPUT.PUT_LINE('## SELECIONAMOS LA UNIDAD DE TRANSPORTE DISPONIBLE MAS PROXIMA A LA SUCURSAL (' || id_sucur || ')');
    elegir_unidad_disponible_proxima(id_sucur, pedido.ID_APP, id_uni, id_gar);
    IF id_uni IS NOT NULL THEN
        SELECT UDT.* INTO unidad FROM UNIDADES_DE_TRANSPORTE UDT WHERE UDT.id = id_uni;
        SELECT TDU.* INTO tipo FROM UNIDADES_DE_TRANSPORTE UDT INNER JOIN TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO WHERE UDT.id = id_uni;
        SELECT G.* INTO gar FROM GARAJES G WHERE G.ID = id_gar;
        SELECT S.* INTO sucur FROM SUCURSALES S WHERE S.ID = id_sucur;
        SELECT DIR.* INTO direc FROM DIRECCIONES DIR WHERE DIR.ID = pedido.ID_DIRECCION;
        DBMS_OUTPUT.PUT_LINE('### LA UNIDAD (' || id_uni || ') DEL GARAJE (' || id_gar || ') DE LA APP (' || unidad.ID_APP || ')');
        DBMS_OUTPUT.PUT_LINE('### DEL TIPO ' || tipo.NOMBRE || ' CON UNA DISTANCIA OPERATIVA DE '|| tipo.DISTANCIA_OPERATIVA || ' TOMA EL ENVIO');
        --TODO VARIOS PEDIDOS
        delta := SIM_DATE() + UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS( UBICACION(sucur.UBICACION.latitud, sucur.UBICACION.longitud, pedido.DURACION.fecha_inicio),  UBICACION(gar.UBICACION.latitud, gar.UBICACION.longitud, pedido.DURACION.fecha_inicio), tipo.VELOCIDAD_MEDIA)/24;
        INSERT INTO RUTAS VALUES(
            unidad.ID_APP,
            unidad.ID_GARAJE,
            unidad.ID,
            p_tracking,
            DEFAULT,
            UBICACION(gar.UBICACION.latitud, gar.UBICACION.longitud, SIM_DATE()),
            UBICACION(sucur.UBICACION.latitud, sucur.UBICACION.longitud, delta),
            'PEDIDO',
            NULL);
        ult_ubi := UBICACION(sucur.UBICACION.latitud, sucur.UBICACION.longitud, delta);
        beta := delta + UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, pedido.DURACION.fecha_inicio), UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado), tipo.VELOCIDAD_MEDIA)/24;
        INSERT INTO RUTAS VALUES(
            unidad.ID_APP,
            unidad.ID_GARAJE,
            unidad.ID,
            p_tracking,
            DEFAULT,
            UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado),
            UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, beta),
            'ENVIO',
            NULL);
        delta := beta;
        ult_ubi := UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, delta);
        IF tipo.CANTIDAD_PEDIDOS > 1 THEN
            ped_cur := obtener_pedidos_suscursal(sucur.ID);
            IF ped_cur%NOTFOUND THEN
                DBMS_OUTPUT.PUT_LINE('### LA SUCURSAL (' || sucur.ID || ') NO TIENE OTROS PEDIDOS QUE DESPACHAR');
            END IF;
            LOOP
                FETCH ped_cur INTO ps;
                EXIT WHEN ped_cur%NOTFOUND AND uni_ped < tipo.CANTIDAD_PEDIDOS;
                IF numero_de_rutas(ps.TRACKING) > 0 THEN
                    DBMS_OUTPUT.PUT_LINE('### EL ALCANCE DE LA UNIDAD NO ES SUFICIENTE PARA ENVIAR EL PEDIDO (' || ps.TRACKING || ')');
                    CONTINUE;
                END IF;
                IF alcance_unidad_posible(id_uni, ps.ID_DIRECCION) = 0 THEN
                    CONTINUE;
                end if;
                DBMS_OUTPUT.PUT_LINE('### SE ADICIONA EL PEDIDO (' || ps.TRACKING || ') A LA UNIDAD');
                SELECT DIR.* INTO direc FROM DIRECCIONES DIR WHERE DIR.ID = ps.ID_DIRECCION;
                beta := delta + UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, pedido.DURACION.fecha_inicio), UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado), tipo.VELOCIDAD_MEDIA)/24;
                INSERT INTO RUTAS VALUES(
                    unidad.ID_APP,
                    unidad.ID_GARAJE,
                    unidad.ID,
                    ps.TRACKING,
                    DEFAULT,
                    UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado),
                    UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, beta),
                    'ENVIO',
                    NULL);
                ult_ubi := UBICACION(direc.UBICACION.latitud, direc.UBICACION.longitud, beta);
                delta := beta;
                uni_ped := uni_ped + 1;
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('### LA UNIDAD (' || id_uni || ') NO DISPONE DE CAPACIDAD PARA OTROS PEDIDOS');
        END IF;
        beta := delta + UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(UBICACION(gar.UBICACION.latitud, gar.UBICACION.longitud, pedido.DURACION.fecha_inicio), UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado), tipo.VELOCIDAD_MEDIA)/24;
        INSERT INTO RUTAS VALUES(
                unidad.ID_APP,
                unidad.ID_GARAJE,
                unidad.ID,
                p_tracking,
                DEFAULT,
                UBICACION(ult_ubi.latitud, ult_ubi.longitud, ult_ubi.actualizado),
                UBICACION(gar.UBICACION.latitud, gar.UBICACION.longitud, beta),
                'RETORNO',
                NULL);
    ELSE
        DBMS_OUTPUT.PUT_LINE('### ACTUALMENTE NO SE DISPONEN DE UNIDADES PARA REALIZAR EL ENVIO');
    END IF;
    RETURN;
END;

CREATE OR REPLACE FUNCTION obtener_rutas_de_la_unidad(id_uni INTEGER) RETURN SYS_REFCURSOR
IS
    uni_cur SYS_REFCURSOR;
BEGIN
    OPEN uni_cur FOR
    SELECT
        R.*
    FROM
        PEDIDOS PD
    INNER JOIN
        RUTAS R on PD.TRACKING = R.ID_TRAKING AND R.CANCELADO IS NULL AND R.ID_UNIDAD = id_uni
    WHERE
        PD.DURACION.fecha_fin IS NULL AND PD.CANCELADO IS NULL
    ORDER BY
        R.ID;
    RETURN uni_cur;
END;

CREATE OR REPLACE PROCEDURE procesar_rutas(id_pedido INTEGER)
IS
    unidad_id INTEGER;
    tipo_unidad TIPOS_DE_UNIDADES%ROWTYPE;
    unidad UNIDADES_DE_TRANSPORTE%ROWTYPE;
    uni_cur SYS_REFCURSOR;
    ruta RUTAS%ROWTYPE;
    pedido PEDIDOS%ROWTYPE;
    ult_ubi UBICACION;
    diff_horas NUMBER;
BEGIN
    IF numero_de_rutas(id_pedido) > 1 THEN
        SELECT R.ID_UNIDAD INTO unidad_id FROM RUTAS R WHERE R.ID_TRAKING = id_pedido FETCH FIRST ROW ONLY;
        SELECT UDT.* INTO unidad FROM UNIDADES_DE_TRANSPORTE UDT WHERE UDT.ID = unidad_id;
        SELECT TDU.* INTO tipo_unidad FROM TIPOS_DE_UNIDADES TDU WHERE TDU.ID = unidad.ID_TIPO;
        uni_cur := obtener_rutas_de_la_unidad(unidad_id);
        DBMS_OUTPUT.PUT_LINE('### PROCESANDO RUTAS DEL PEDIDO CON EL ID (' || id_pedido || ')');
       LOOP
            FETCH uni_cur INTO ruta;
            EXIT WHEN uni_cur%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE('### LA RUTA (' || ruta.ID || ') TIENE COMO PROPÓSITO ' || ruta.PROPOSITO);
            SELECT PD.* INTO pedido FROM PEDIDOS PD WHERE PD.TRACKING = ruta.ID_TRAKING;
            IF pedido.CANCELADO IS NOT NULL OR pedido.DURACION.fecha_fin IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('### LA RUTA (' || ruta.ID || ') YA FUÉ CULMINADA');
                CONTINUE;
            END IF;
            diff_horas := SIM_DATE() - CAST(ruta.ORIGEN.actualizado AS DATE);
            IF diff_horas < 0 THEN
                EXIT;
            END IF;
            ult_ubi := UBICACION.OBTENER_POSICION(UBICACION(ruta.DESTINO.latitud, ruta.DESTINO.longitud, ruta.DESTINO.actualizado), UBICACION(ruta.ORIGEN.latitud, ruta.ORIGEN.longitud, ruta.ORIGEN.actualizado),tipo_unidad.VELOCIDAD_MEDIA, diff_horas);
            IF ult_ubi.actualizado <= SIM_DATE() THEN
                DBMS_OUTPUT.PUT_LINE('### LA RUTA (' || ruta.ID || ') YA SE ENCUENTRA FINALIZADA');
                IF ruta.PROPOSITO = 'ENVIO' THEN
                    DBMS_OUTPUT.PUT_LINE('### SE CULMINA EL PEDIDO ('|| pedido.TRACKING || ') EN LA RUTA (' || ruta.ID || ')');
                END IF;
            END IF;
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('### EL PEDIDO CON EL ID (' || id_pedido || ') FUE PROCESADO EN LA RUTA DE OTRO PEDIDO');
    END IF;
    RETURN;
END;

-- ENVIOS
CREATE OR REPLACE PROCEDURE realizar_envios
IS
    pedidos_cur SYS_REFCURSOR;
    pedido PEDIDOS%ROWTYPE;
BEGIN
    pedidos_cur := obtener_pedidos();
    LOOP
        FETCH pedidos_cur INTO pedido;
        EXIT WHEN pedidos_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('### SE SELECIONA EL PEDIDO CON EL NÚMERO DE TRACKING (' || pedido.TRACKING || ')');
        IF numero_de_rutas(pedido.TRACKING) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('### EL PEDIDO CON EL NÚMERO DE TRACKING (' || pedido.TRACKING || ') DEL ' || pedido.DURACION.fecha_inicio || ' NO SE HA RECOGIDO');
            crear_rutas(pedido.TRACKING);
            DBMS_OUTPUT.PUT_LINE('### EL PEDIDO CON EL NÚMERO DE TRACKING (' || pedido.TRACKING || ') DEL ' || pedido.DURACION.fecha_inicio || ' NO SE HA RECOGIDO');
        ELSE
            DBMS_OUTPUT.PUT_LINE('### EL PEDIDO CON EL NÚMERO DE TRACKING(' || pedido.TRACKING || ') YA TIENE RUTA ASIGNADA');
            procesar_rutas(pedido.TRACKING);
        END IF;
    END LOOP;
END;

CALL generar_pedido(5);
CALL UPDATE_SIM_TIME('PRIMER AVANCE');
CALL UPDATE_SIM_TIME('SEGUNDO AVANCE');
-- TODO FINALIZAR RUTAS
CALL realizar_envios();

SELECT P.*, SIM_DATE() D FROM PEDIDOS P;
SELECT R.* FROM RUTAS R WHERE ID_UNIDAD=232;
UPDATE PEDIDOS SET CANCELADO = NULL WHERE TRACKING=170;
SELECT unidad_libre(504) FROM DUAL;

SELECT * FROM sucursales WHERE ID=92;
