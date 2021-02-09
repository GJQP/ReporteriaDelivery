-- CUENTAS USUARIOS

-- cuentas transportistas
create user c##Transportista1 identified by password;
GRANT CONNECT, RESOURCE TO c##Transportista1;
GRANT c##Transportista_ROL TO c##Transportista1;

create user c##Transportista2 identified by password;
GRANT CONNECT, RESOURCE TO c##Transportista2;
GRANT c##Transportista_ROL TO c##Transportista2;

--cuentas appdelivery
create user c##AppDelivery1 identified by password;
GRANT CONNECT, RESOURCE TO c##AppDelivery1;
GRANT c##AppDelivery_ROL TO c##AppDelivery1;

create user c##AppDelivery2 identified by password;
GRANT CONNECT, RESOURCE TO c##AppDelivery2;
GRANT c##AppDelivery_ROL TO c##AppDelivery2;