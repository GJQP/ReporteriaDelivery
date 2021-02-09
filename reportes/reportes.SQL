CREATE OR REPLACE FUNCTION buscar(l_palabra VARCHAR2, busq VARCHAR2)
    RETURN NUMBER
    IS
BEGIN
    RETURN INSTR(l_palabra, busq);
END;

CREATE OR REPLACE PROCEDURE reporte1(test_cur OUT SYS_REFCURSOR) IS
BEGIN
    OPEN test_cur FOR
        SELECT TREAT(aplicaciones_delivery.app AS MARCA).logo                  AS logo,
               TREAT(aplicaciones_delivery.app AS MARCA).nombre                AS nombre,
               planes_de_servicio.cantidad_envios,
               planes_de_servicio.modalidad,
               TREAT(planes_de_servicio.duracion AS RANGO_TIEMPO).fecha_inicio AS fecha_inicio,
               TREAT(planes_de_servicio.duracion AS RANGO_TIEMPO).fecha_fin    AS fecha_fin,
               planes_de_servicio.precio
        FROM planes_de_servicio
                 INNER JOIN
             aplicaciones_delivery
             ON
                     planes_de_servicio.id_app = aplicaciones_delivery.id AND planes_de_servicio.cancelado IS NULL
        ORDER BY nombre, TREAT(planes_de_servicio.duracion AS RANGO_TIEMPO).fecha_inicio;
END;

CREATE OR REPLACE PROCEDURE reporte2(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL)
    IS
BEGIN

    IF p_estado IS NOT NULL THEN
        OPEN test_cur FOR
            SELECT ep.empresa.logo               logo,
                   ep.empresa.nombre             nombre,
                   s.*,
                   (SELECT LISTAGG(est.nombre, ', ') WITHIN GROUP (ORDER BY est.nombre)
                    FROM estados est
                             INNER JOIN ubicaciones_aplicables ua ON est.id = ua.id_estado
                    WHERE ua.id_plan = s.id_pan) estados
            FROM (SELECT c.id_empresa                                   empresa_id,
                         ad.app.nombre                                  nombre_app,
                         TO_CHAR(c.duracion.fecha_inicio, 'DD-MM-YYYY') fecha_registro,
                         TO_CHAR(c.duracion.fecha_inicio, 'DD-MM-YYYY') fecha_inicio,
                         TO_CHAR(c.duracion.fecha_fin, 'DD-MM-YYYY')    fecha_fin,
                         c.porcentaje_descuento                         descuento,
                         ps.modalidad                                   modalidad,
                         ps.cantidad_envios                             cantidad_envios,
                         ps.precio                                      precio,
                         ps.id                                          id_pan
                  FROM planes_de_servicio ps
                           INNER JOIN
                       aplicaciones_delivery ad ON ad.id = ps.id_app
                           INNER JOIN
                       ubicaciones_aplicables uap ON uap.id_app = ps.id_app AND uap.id_plan = ps.id
                           INNER JOIN
                       estados e ON e.id = uap.id_estado
                           INNER JOIN
                       ubicaciones_aplicables ubi
                       ON ubi.id_app = ps.id_app AND ubi.id_plan = ps.id AND ubi.id_estado = e.id
                           INNER JOIN
                       contratos c ON c.id_plan = ps.id AND c.id_app = ps.id_app AND c.cancelado IS NULL
                  WHERE ps.cancelado IS NULL
                    AND 0 < buscar(p_estado, e.nombre)
                  GROUP BY c.id_empresa,
                           ad.app.nombre,
                           c.duracion.fecha_inicio,
                           c.duracion.fecha_fin,
                           ps.modalidad,
                           ps.cantidad_envios,
                           ps.precio,
                           c.porcentaje_descuento,
                           ps.id
                  ORDER BY ad.app.nombre,
                           c.duracion.fecha_inicio) s
                     INNER JOIN
                 empresas ep ON ep.id = s.empresa_id
            ORDER BY 2;
    ELSIF p_estado IS NULL THEN
        OPEN test_cur FOR
            SELECT ep.empresa.logo   logo,
                   ep.empresa.nombre nombre,
                   s.*
            FROM (SELECT c.id_empresa                                                empresa_id,
                         ad.app.nombre                                               nombre_app,
                         TO_CHAR(c.duracion.fecha_inicio, 'DD-MM-YYYY')              fecha_registro,
                         TO_CHAR(c.duracion.fecha_inicio, 'DD-MM-YYYY')              fecha_inicio,
                         TO_CHAR(c.duracion.fecha_fin, 'DD-MM-YYYY')                 fecha_fin,
                         c.porcentaje_descuento                                      descuento,
                         ps.modalidad                                                modalidad,
                         ps.cantidad_envios                                          cantidad_envios,
                         ps.precio                                                   precio,
                         LISTAGG(e.nombre, ', ') WITHIN GROUP (ORDER BY e.nombre) AS estados
                  FROM planes_de_servicio ps
                           INNER JOIN
                       aplicaciones_delivery ad ON ad.id = ps.id_app
                           INNER JOIN
                       ubicaciones_aplicables uap ON uap.id_app = ps.id_app AND uap.id_plan = ps.id
                           INNER JOIN
                       estados e ON e.id = uap.id_estado
                           INNER JOIN
                       contratos c ON c.id_plan = ps.id AND c.id_app = ps.id_app AND c.cancelado IS NULL
                  WHERE ps.cancelado IS NULL
                  GROUP BY c.id_empresa,
                           ad.app.nombre,
                           c.duracion.fecha_inicio,
                           c.duracion.fecha_fin,
                           ps.modalidad,
                           ps.cantidad_envios,
                           ps.precio,
                           c.porcentaje_descuento
                  ORDER BY ad.app.nombre,
                           c.duracion.fecha_inicio) s
                     INNER JOIN
                 empresas ep ON ep.id = s.empresa_id
            ORDER BY 2;

    END IF;
END;

CREATE OR REPLACE PROCEDURE reporte3(test_cur OUT SYS_REFCURSOR, sector VARCHAR2 DEFAULT NULL,
                                     fecha_ini DATE DEFAULT NULL, fecha_fin DATE DEFAULT NULL,
                                     estado_nombre VARCHAR2 DEFAULT NULL)
    IS
BEGIN

    OPEN test_cur FOR
        SELECT s.*,
               TREAT(ap.app AS MARCA).logo     logo_app,
               TREAT(ep.empresa AS MARCA).logo logo_empresa
        FROM (
                 SELECT pd.id_app                                              idapp,
                        pd.id_empresa                                          idempresa,
                        e.nombre                                               nomestado,
                        TREAT(ep.empresa AS MARCA).nombre                      nombre_emp,
                        TREAT(ad.app AS MARCA).nombre                          nombre_app,
                        sdc.nombre,
                        COUNT(pd.tracking) AS                                  cantidad_pedidos,
                        TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_inicio) fi,
                        TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_fin)    ff
                 FROM pedidos pd
                          INNER JOIN
                      empresas ep ON ep.id = pd.id_empresa
                          INNER JOIN
                      aplicaciones_delivery ad ON ad.id = pd.id_app
                          INNER JOIN
                      estados e ON e.id = pd.id_estado
                          INNER JOIN
                      sectores_de_comercio sdc ON sdc.id = ep.id_sector
                 WHERE pd.cancelado IS NULL
                   AND (fecha_ini IS NULL OR TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_inicio) >= TRUNC(fecha_ini))
                   AND (fecha_fin IS NULL OR TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_fin) <= TRUNC(fecha_fin))
                   AND (sector IS NULL OR 0 < buscar(sector, sdc.nombre))
                   AND (estado_nombre IS NULL OR 0 < buscar(estado_nombre, e.nombre))
                 GROUP BY pd.id_app,
                          pd.id_empresa,
                          TREAT(ep.empresa AS MARCA).nombre,
                          TREAT(ad.app AS MARCA).nombre,
                          sdc.nombre,
                          e.nombre,
                          TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_inicio),
                          TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_fin)
                 ORDER BY pd.id_empresa,
                          pd.id_app,
                          e.nombre,
                          TRUNC(TREAT(pd.duracion AS RANGO_TIEMPO).fecha_inicio)
             ) s
                 INNER JOIN
             empresas ep ON ep.id = s.idempresa
                 INNER JOIN
             aplicaciones_delivery ap ON ap.id = s.idapp;

END;

CREATE OR REPLACE PROCEDURE reporte4(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL)
    IS
BEGIN
    OPEN test_cur FOR
        SELECT s.*, TREAT(ex.app AS MARCA).logo logo_app
        FROM (
                 SELECT ad.id                                          appi,
                        TREAT(ad.app AS MARCA).nombre                  nombre_app,
                        e.nombre                                       nombre_estado,
                        tdu.nombre                                     nombre_tipo,
                        SUM(DECODE(udt.estado, 'OPERATIVA', 1, 0))  AS unidades_op,
                        SUM(DECODE(udt.estado, 'REPARACION', 1, 0)) AS unidades_rep
                 FROM garajes
                          INNER JOIN
                      aplicaciones_delivery ad ON ad.id = garajes.id_app
                          INNER JOIN
                      unidades_de_transporte udt ON garajes.id_app = udt.id_app AND garajes.id = udt.id_garaje
                          INNER JOIN
                      tipos_de_unidades tdu ON udt.id_tipo = tdu.id
                          INNER JOIN
                      estados e ON garajes.id_estado = e.id
                 GROUP BY TREAT(ad.app AS MARCA).nombre,
                          e.nombre,
                          tdu.nombre,
                          ad.id
                 ORDER BY TREAT(ad.app AS MARCA).nombre,
                          e.nombre,
                          tdu.nombre
             ) s
                 INNER JOIN
             aplicaciones_delivery ex
             ON ex.id = s.appi AND ((p_estado IS NULL) OR 0 < buscar(p_estado, s.nombre_estado));
END;

CREATE OR REPLACE PROCEDURE reporte6(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL,
                                     p_fecha_registro DATE DEFAULT NULL)
    IS
BEGIN
    OPEN test_cur FOR
        SELECT usuarios.foto,
               usuarios.primer_nombre,
               usuarios.segundo_nombre,
               usuarios.primer_apellido,
               usuarios.segundo_apellido,
               usuarios.tipo_de_cedula,
               usuarios.numero_de_cedula,
               --TREAT(USUARIOS.ESTADO AS RANGO_TIEMPO) FECHA_NACIMIENTO,
               usuarios.email,
               TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio,
               TREAT(ad.app AS MARCA).nombre nombre_app,
               TREAT(ad.app AS MARCA).logo   logo_app,
               d.descripcion,
               e.nombre
        FROM usuarios
                 INNER JOIN
             registros r ON usuarios.id = r.id_usuario
                 INNER JOIN
             aplicaciones_delivery ad ON r.id_app = ad.id
                 INNER JOIN
             direcciones d ON usuarios.id = d.id_usuario
                 INNER JOIN
             estados e ON e.id = d.id_estado
        WHERE r.registro.fecha_fin IS NULL
          AND (p_estado IS NULL OR 0 < buscar(p_estado, e.nombre))
          AND (p_fecha_registro IS NULL OR TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio >= p_fecha_registro)
        ORDER BY e.nombre,
                 r.registro.fecha_inicio;

END;



CREATE OR REPLACE PROCEDURE reporte6(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL,
                                     p_fecha_registro DATE DEFAULT NULL)
    IS
BEGIN
    OPEN test_cur FOR
        SELECT s.*, u.foto foto, TREAT(app.app AS MARCA).logo logo_app
        FROM (SELECT
                  --USUARIOS.FOTO,
                  usuarios.primer_nombre,
                  usuarios.segundo_nombre,
                  usuarios.primer_apellido,
                  usuarios.segundo_apellido,
                  usuarios.tipo_de_cedula,
                  usuarios.numero_de_cedula,
                  usuarios.email,
                  TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio,
                  TREAT(ad.app AS MARCA).nombre nombre_app,
                  MAX(d.descripcion)            descripcion,
                  e.nombre,
                  d.id_estado,
                  ad.id                         app_id,
                  usuarios.id                   u_id
              FROM usuarios
                       INNER JOIN
                   registros r ON usuarios.id = r.id_usuario
                       INNER JOIN
                   aplicaciones_delivery ad ON r.id_app = ad.id
                       INNER JOIN
                   direcciones d ON usuarios.id = d.id_usuario
                       INNER JOIN
                   estados e ON e.id = d.id_estado
              WHERE r.registro.fecha_fin IS NULL
                AND (p_estado IS NULL OR 0 < buscar(p_estado, e.nombre))
                AND (p_fecha_registro IS NULL OR TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio >= p_fecha_registro)
              GROUP BY d.id_estado,
                       e.nombre,
                       e.id,
                       ad.id,
                       usuarios.primer_nombre,
                       usuarios.segundo_nombre,
                       usuarios.primer_apellido,
                       usuarios.segundo_apellido,
                       usuarios.tipo_de_cedula,
                       usuarios.numero_de_cedula,
                       usuarios.id,
                       TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio,
                       TREAT(ad.app AS MARCA).nombre,
                       usuarios.email
              ORDER BY e.nombre,
                       MAX(TREAT(r.registro AS RANGO_TIEMPO).fecha_inicio)) s,
             usuarios u,
             aplicaciones_delivery app
        WHERE app.id = s.app_id
          AND u.id = s.u_id
        ORDER BY s.app_id;

END;



CREATE OR REPLACE PROCEDURE pruebaimagenes(test_cur OUT SYS_REFCURSOR) IS
BEGIN
    OPEN test_cur FOR
        SELECT TREAT(aplicaciones_delivery.app AS MARCA).logo   AS logo,
               TREAT(aplicaciones_delivery.app AS MARCA).nombre AS nombre
        FROM aplicaciones_delivery;
END;


CREATE OR REPLACE PROCEDURE pruebaimagenes2(test_cur OUT SYS_REFCURSOR) IS
BEGIN
    OPEN test_cur FOR
        SELECT TREAT(empresas.empresa AS MARCA).logo   AS logo,
               TREAT(empresas.empresa AS MARCA).nombre AS nombre
        FROM empresas;
END;

CREATE OR REPLACE PROCEDURE pruebaimagenes3(test_cur OUT SYS_REFCURSOR) IS
BEGIN
    OPEN test_cur FOR
        SELECT foto FROM usuarios;
END;


CREATE OR REPLACE PROCEDURE reporte5(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL)
    IS
BEGIN
    OPEN test_cur FOR
        SELECT s.nombre_estado,
               s.nombre_municipio,
               s.nombre_empresa,
               s.nombre_app,
               s.numero_pedidos,
               TREAT(emp.empresa AS MARCA).logo AS logo_emp,
               TREAT(apps.app AS MARCA).logo    AS logo_app
        FROM (SELECT e.id               id_estado,
                     emp.id             id_emp,
                     app.id             id_app,
                     e.nombre           nombre_estado,
                     mun.nombre         nombre_municipio,
                     ROW_NUMBER() OVER (
                         PARTITION BY e.id, mun.id
                         ORDER BY COUNT(pe.tracking) DESC
                         )              row_number,
                     COUNT(pe.tracking) numero_pedidos,
                     app.app.nombre     nombre_app,
                     emp.empresa.nombre nombre_empresa
              FROM pedidos pe,
                   direcciones dir,
                   estados e,
                   municipios mun,
                   empresas emp,
                   aplicaciones_delivery app
              WHERE pe.cancelado IS NULL
                AND pe.duracion.fecha_fin IS NOT NULL
                AND dir.id = pe.id_direccion
                AND e.id = dir.id_estado
                AND mun.id = dir.id_municipio
                AND emp.id = pe.id_empresa
                AND app.id = pe.id_app
                AND (p_estado IS NULL OR 0 < buscar(p_estado, e.nombre))
              GROUP BY e.nombre, app.app.nombre, emp.empresa.nombre, mun.nombre, e.id, emp.id, app.id, mun.id
              ORDER BY e.nombre, MAX(pe.duracion.fecha_fin) DESC, mun.nombre) s,
             aplicaciones_delivery apps,
             empresas emp
        WHERE row_number <= 5
          AND s.id_emp = emp.id
          AND s.id_app = apps.id
        ORDER BY nombre_estado, numero_pedidos DESC;
END;

-- NOTA: EL REPORTE 7 SE TRAE TODOS SIN IMPORTAR SI HAN FINALIZADO.
CREATE OR REPLACE PROCEDURE reporte7(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL,
                                     fecha_ini DATE DEFAULT NULL,fecha_fin DATE DEFAULT NULL,p_app VARCHAR2 DEFAULT NULL)
IS
BEGIN
OPEN test_cur FOR
SELECT
       s.*,
       TREAT(app.APP AS MARCA).nombre NOMBRE_APP,
       TREAT(app.APP AS MARCA).logo LOGO_APP
FROM (
         SELECT e.NOMBRE                                       ESTADO,
                dir.descripcion                                DESCRIPCION,
                dir.referencia                                 REFERENCIA,
                p.tracking                                     TRACKING,
                TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio FECHA_INICIO,
                TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin    FECHA_FIN,
                COUNT(de.cantidad) CANTIDAD,
                p.id_app APP_ID,
                u.email
         FROM PEDIDOS p,
              ESTADOS e,
              DIRECCIONES dir,
              DETALLES de,
              USUARIOS u,
              APLICACIONES_DELIVERY app
         WHERE e.id = p.id_estado
           AND dir.id = p.id_direccion
           AND de.ID_TRACKING = p.tracking
           AND u.id = p.id_usuario
           AND app.id = p.id_app
           AND (fecha_ini IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio) >= TRUNC(fecha_ini))
           AND (fecha_fin IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin) <= TRUNC(fecha_fin))
           AND (p_app IN ('[]','null') OR 0< buscar(p_app, TREAT(app.APP AS MARCA).nombre))
           AND (p_estado IN ('[]','null') OR 0 < buscar(p_estado, e.nombre))
         GROUP BY dir.descripcion,
                  e.NOMBRE,
                  dir.referencia,
                  p.tracking,
                  TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio,
                  TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin,
                  u.email,
                  p.id_app
         ORDER BY TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio,
                  TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin,
                  p.tracking
     ) s, APLICACIONES_DELIVERY app
    WHERE app.id = s.APP_ID;
end;

CREATE OR REPLACE PROCEDURE reporte9(test_cur OUT SYS_REFCURSOR, p_estado VARCHAR2 DEFAULT NULL,
                                     fecha_ini DATE DEFAULT NULL,fecha_fin DATE DEFAULT NULL,p_zona VARCHAR2 DEFAULT NULL)
IS
BEGIN
OPEN test_cur FOR
SELECT s.* FROM
(SELECT
    MIN(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio) FECHA_INICIO,
    MAX(TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin) FECHA_FIN,
    e.nombre NOMBRE_ESTADO,
    z.nombre NOMBRE_ZONA,
    sec.nombre SECTOR_COMERCIO,
    SUM(d.cantidad) CANTIDAD_PRODUCTOS,
    ROW_NUMBER() OVER (
         PARTITION BY e.NOMBRE, z.nombre
         ORDER BY SUM(d.cantidad) DESC
    )  row_number
FROM pedidos p, detalles d, productos pro, sectores_de_comercio sec,estados e, zonas z
WHERE
    d.ID_TRACKING = p.TRACKING
    AND e.ID = p.ID_ESTADO
    AND z.ID = p.ID_ZONA
    AND pro.ID = d.ID_PRODUCTO
    AND sec.ID = pro.ID_SECTOR
    AND TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin IS NOT NULL
    AND (fecha_ini IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio) >= TRUNC(fecha_ini))
    AND (fecha_fin IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin) <= TRUNC(fecha_fin))
    AND (p_estado IN ('[]','null') OR 0 < buscar(p_estado, e.nombre))
    AND (p_zona IN ('[]','null') OR 0 < buscar(p_zona, z.nombre))
GROUP BY
    e.nombre,z.nombre,sec.nombre
ORDER BY
    e.nombre,
    z.nombre,
    SUM(d.cantidad) DESC,
    MIN(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio)) s
WHERE s.row_number <=5;
end;

CREATE OR REPLACE PROCEDURE reporte10(test_cur OUT SYS_REFCURSOR, p_app VARCHAR2 DEFAULT NULL,
                                     fecha_ini DATE DEFAULT NULL,fecha_fin DATE DEFAULT NULL)
IS
BEGIN
OPEN test_cur FOR
SELECT
       s.*,
       TREAT(app.APP AS MARCA).nombre NOMBRE_APP,
       TREAT(app.APP AS MARCA).logo LOGO_APP,
       TREAT(emp.EMPRESA AS MARCA).nombre NOMBRE_EMP,
       TREAT(emp.EMPRESA AS MARCA).logo LOGO_EMP
FROM
(SELECT
    MIN(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio) FECHA_INICIO,
    MAX(TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin) FECHA_FIN,
    p.ID_APP ID_APP,
    p.ID_EMPRESA ID_EMPRESA,
    SUM(p.total) INGRESOS
FROM PEDIDOS p, APLICACIONES_DELIVERY app
WHERE
    (p_app IN ('[]','null') OR 0< buscar(p_app, TREAT(app.APP AS MARCA).nombre))
    AND p.ID_APP = app.ID
    AND (fecha_ini IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_inicio) >= TRUNC(fecha_ini))
    AND (fecha_fin IS NULL OR TRUNC(TREAT(p.duracion AS RANGO_TIEMPO).fecha_fin) <= TRUNC(fecha_fin))
GROUP BY
    p.ID_APP, p.ID_EMPRESA
ORDER BY
    p.ID_EMPRESA, p.ID_APP
) s, APLICACIONES_DELIVERY app, EMPRESAS emp
WHERE
    app.ID = s.ID_APP
    AND emp.ID = s.ID_EMPRESA;
end;




--ENTREGA 3

CREATE OR REPLACE PROCEDURE reporte8(cur_rep OUT SYS_REFCURSOR, p_tracking VARCHAR2) IS
BEGIN
    OPEN cur_rep FOR
        SELECT p.tracking                                                           AS tracking,
               p.duracion.fecha_inicio                                              AS f_inicio,
               r.origen.actualizado +
               ubicacion.obtener_tiempo_estimado_en_horas(r.origen,
                                                          d2.ubicacion,
                                                          tdu.velocidad_media) / 24 AS f_fin,
               --,
               (SELECT COUNT(*) FROM detalles d WHERE p.tracking = d.id_tracking)   AS c_prod,
               u.email                                                              AS correo,
               TRUNC(ubicacion.obtener_tiempo_estimado_en_horas(r.origen,
                                                                d2.ubicacion,
                                                                tdu.velocidad_media)
                   )
                   || ':' ||
               TRIM(
                       TO_CHAR(
                               MOD(ubicacion.obtener_tiempo_estimado_en_horas(r.origen,
                                                                              d2.ubicacion,
                                                                              tdu.velocidad_media) * 60,
                                   60),
                               '09'
                           ))
                   || 'h'                                                           AS t_estimado,
               OBTENER_MAPA_LAT(r.origen,
                            r.destino,
                            tdu.velocidad_media)  as lat,
               OBTENER_MAPA_LONG(r.origen,
                            r.destino,
                            tdu.velocidad_media)                                    AS longitud
        FROM pedidos p
                 INNER JOIN (SELECT MAX(r.id) AS id, p.tracking
                             FROM pedidos p
                                      INNER JOIN rutas r ON p.tracking = r.id_traking
                             WHERE r.proposito != 'RETORNO'
                             GROUP BY p.tracking) ru ON ru.tracking = p.tracking
                 INNER JOIN rutas r ON ru.id = r.id
                 INNER JOIN direcciones d2
                            ON d2.id_estado = p.id_estado AND d2.id_municipio = p.id_municipio AND
                               d2.id_zona = p.id_zona AND
                               d2.id_usuario = p.id_usuario AND d2.id = p.id_direccion
                 INNER JOIN unidades_de_transporte udt ON r.id_unidad = udt.id
                 INNER JOIN tipos_de_unidades tdu ON udt.id_tipo = tdu.id
                 INNER JOIN usuarios u ON p.id_usuario = u.id
        WHERE r.cancelado IS NULL
          AND p.cancelado IS NULL
          AND p.duracion.fecha_fin IS NULL
          AND (p_tracking IN ('[]','null') OR 0 < BUSCAR(p_tracking,p.tracking));
END;

CREATE OR REPLACE PROCEDURE reporte12(cur_rep OUT SYS_REFCURSOR, p_origen VARCHAR2, p_destino VARCHAR2) IS
BEGIN
    OPEN cur_rep FOR
        SELECT ad.app.logo          AS logo,
               zo.nombre            AS origen,
               zd.nombre            AS destino,
               tet.tiempo || ' min' AS llegada,
               tet.nombre           AS tipo
        FROM (SELECT tdu.nombre,
                     pdz.id_empresa,
                     TRUNC(AVG(p.duracion.fecha_fin - p.duracion.fecha_inicio) * 24 * 60) tiempo,
                     pdz.origen,
                     pdz.destino
              FROM pedidos p
                       INNER JOIN (SELECT p.tracking, p.id_empresa, s.id_zona AS origen, d.id_zona AS destino
                                   FROM pedidos p
                                            INNER JOIN (SELECT DISTINCT d.id_sucursal, d.id_tracking FROM detalles d) sc
                                                       ON sc.id_tracking = p.tracking
                                            INNER JOIN sucursales s ON sc.id_sucursal = s.id
                                            INNER JOIN direcciones d
                                                       ON p.id_estado = d.id_estado AND
                                                          p.id_municipio = d.id_municipio AND
                                                          p.id_zona = d.id_zona AND p.id_usuario = d.id_usuario AND
                                                          p.id_direccion = d.id) pdz ON p.tracking = pdz.tracking
                       INNER JOIN rutas r ON p.tracking = r.id_traking
                       INNER JOIN unidades_de_transporte udt ON r.id_unidad = udt.id
                       INNER JOIN tipos_de_unidades tdu ON tdu.id = udt.id_tipo
              WHERE p.duracion.fecha_fin IS NOT NULL
                AND p.cancelado IS NULL
              GROUP BY tdu.nombre, pdz.id_empresa, pdz.origen, pdz.destino) tet
             INNER JOIN aplicaciones_delivery ad ON tet.id_empresa = ad.id
             INNER JOIN zonas zo ON tet.origen = zo.id
             INNER JOIN zonas zd ON tet.destino = zd.id
    WHERE (p_origen IN ('[]','null') OR 0 < BUSCAR(p_origen,zo.nombre))
    AND (p_destino IN ('[]','null') OR 0 < BUSCAR(p_destino,zd.nombre))
    ;
END;

CREATE OR REPLACE PROCEDURE reporteX(cur_rep OUT SYS_REFCURSOR, p_origen VARCHAR2)
IS
BEGIN
    OPEN cur_rep FOR
        SELECT DECODE(p_origen,'[]','siii',DECODE(p_origen,'null','es null','me rindo')) as prueba

             , 'help' as t FROM dual
        WHERE p_origen IN('[]','null');
END;

CREATE OR REPLACE PROCEDURE reporte13(cur_rep OUT SYS_REFCURSOR, p_fecha_ini DATE DEFAULT NULL, p_fecha_fin DATE DEFAULT NULL) AS
BEGIN
    OPEN cur_rep FOR
        SELECT
            S.*, (SELECT ADA.APP.LOGO FROM APLICACIONES_DELIVERY ADA WHERE ADA.ID = S.ID) LOGO
        FROM (
            SELECT
                MIN(PED.DURACION.FECHA_INICIO) fecha_inicio,
                MAX(PED.DURACION.FECHA_FIN) fecha_fin,
                TO_CHAR(AVG(PED.VALORACION),'0.99') VALORACION,
                AD2.ID,
                TREAT(AD2.APP AS MARCA).NOMBRE NOMBRE
            FROM
                PEDIDOS PED
            INNER JOIN
                APLICACIONES_DELIVERY AD2 ON AD2.ID = PED.ID_APP
            WHERE
                (TRUNC(PED.DURACION.FECHA_INICIO) >= p_fecha_ini OR p_fecha_ini IS NULL) AND (TRUNC(PED.DURACION.FECHA_FIN) <= p_fecha_fin OR p_fecha_fin IS NULL) AND PED.CANCELADO IS NULL
            GROUP BY
                AD2.ID,
                TREAT(AD2.APP AS MARCA).NOMBRE
            ) S
        ORDER BY
            VALORACION;
END;

-- Función de validación
CREATE OR REPLACE FUNCTION validarTop(ID_EST INTEGER, ID_APP INTEGER, p_fecha_ini DATE DEFAULT NULL, p_fecha_fin DATE DEFAULT NULL) RETURN INTEGER IS
    t_cur SYS_REFCURSOR;
    APPLI INT;
    times INT;
    ESTADUS INT;
BEGIN
    times := 0;
    OPEN t_cur FOR
        SELECT
            S.APP APP, S.ID_ESTADO ESTA
        FROM
             (SELECT
                MIN(PED.DURACION.FECHA_INICIO) fecha_inicio,
                MAX(PED.DURACION.FECHA_FIN) fecha_fin,
                COUNT(PED.TRACKING) CANTIDAD,
                AD2.ID APP,
                TREAT(AD2.APP AS MARCA).NOMBRE NOMBRE,
                E.ID ID_ESTADO,
                E.NOMBRE ESTADO
            FROM
                PEDIDOS PED
            INNER JOIN
                APLICACIONES_DELIVERY AD2 ON AD2.ID = PED.ID_APP
            INNER JOIN
                ESTADOS E ON E.ID = PED.ID_ESTADO
            WHERE
                (TRUNC(PED.DURACION.FECHA_FIN) <= p_fecha_fin OR p_fecha_fin IS NULL) AND
                (TRUNC(PED.DURACION.FECHA_INICIO) >= p_fecha_ini OR p_fecha_ini IS NULL) AND
                (PED.CANCELADO IS NULL)
            GROUP BY
                AD2.ID,
                E.ID,
                TREAT(AD2.APP AS MARCA).NOMBRE,
                E.NOMBRE
            ORDER BY
                E.NOMBRE,
                CANTIDAD DESC
            ) S;
    LOOP
        FETCH t_cur INTO APPLI, ESTADUS;
        EXIT WHEN t_cur%NOTFOUND;
        IF ESTADUS = ID_EST THEN
            times := times + 1;
        end if;
        IF APPLI = ID_APP AND times < 4 THEN
            RETURN 1;
        ELSIF times > 3 THEN
            return 0;
        end if;
    end loop;
    return 0;
END;

CREATE OR REPLACE PROCEDURE reporte11(cur_rep OUT SYS_REFCURSOR, p_fecha_ini DATE DEFAULT NULL, p_fecha_fin DATE DEFAULT NULL, p_zona VARCHAR2 DEFAULT NULL) AS
BEGIN
    OPEN cur_rep FOR
        SELECT
            S.*, (SELECT ADA.APP.LOGO FROM APLICACIONES_DELIVERY ADA WHERE ADA.ID = S.APP) LOGO
        FROM (
            SELECT
                TO_CHAR(MIN(PED.DURACION.FECHA_INICIO), 'dd/mm/yyyy') fecha_inicio,
                TO_CHAR(MAX(PED.DURACION.FECHA_FIN), 'dd/mm/yyyy') fecha_fin,
                COUNT(PED.TRACKING) CANTIDAD,
                AD2.ID APP,
                TREAT(AD2.APP AS MARCA).NOMBRE NOMBRE,
                E.ID ID_ESTADO,
                E.NOMBRE ESTADO
            FROM
                PEDIDOS PED
            INNER JOIN
                APLICACIONES_DELIVERY AD2 ON AD2.ID = PED.ID_APP
            INNER JOIN
                ESTADOS E ON E.ID = PED.ID_ESTADO
            WHERE
                (TRUNC(PED.DURACION.FECHA_FIN) <= p_fecha_fin OR p_fecha_fin IS NULL) AND
                (TRUNC(PED.DURACION.FECHA_INICIO) >= p_fecha_ini OR p_fecha_ini IS NULL) AND
                (PED.CANCELADO IS NULL)
            GROUP BY
                AD2.ID,
                E.ID,
                TREAT(AD2.APP AS MARCA).NOMBRE,
                E.NOMBRE
            ORDER BY
                E.NOMBRE,
                CANTIDAD DESC
            ) S
        WHERE
           1 = validarTop(S.ID_ESTADO, S.APP, p_fecha_ini, p_fecha_fin) AND
           (p_zona IN ('[]','null') OR 0 < BUSCAR(p_zona,S.ESTADO));
END;