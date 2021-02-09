-- CUENTAS USUARIOS

-- cuentas transportistas
create user c##Transportista1 identified by password;
GRANT CONNECT, RESOURCE TO c##Transportista1;
GRANT c##Transportista_ROL TO c##Transportista1;

create user c##Transportista2 identified by password;
GRANT CONNECT, RESOURCE TO c##Transportista2;
GRANT c##Transportista_ROL TO c##Transportista2;

