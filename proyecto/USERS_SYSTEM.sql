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

-- cuentas sucursal
create user c##Sucursal1 identified by password;
GRANT CONNECT, RESOURCE TO c##Sucursal1;
GRANT c##Sucursal_ROL TO c##Sucursal1;

create user c##Sucursal2 identified by password;
GRANT CONNECT, RESOURCE TO c##Sucursal2;
GRANT c##Sucursal_ROL TO c##Sucursal2;


-- empresas
create user c##Empresa1 identified by password;
GRANT CONNECT, RESOURCE TO c##Empresa1;
GRANT c##Empresa_ROL TO c##Empresa1;

create user c##Empresa2 identified by password;
GRANT CONNECT, RESOURCE TO c##Empresa2;
GRANT c##Empresa_ROL TO c##Empresa1;

-- usuario final
create user c##usuario1 identified by password;
GRANT CONNECT, RESOURCE TO c##usuario1;
GRANT c##UsuarioFinal_ROL TO c##usuario1;

create user c##usuario2 identified by password;
GRANT CONNECT, RESOURCE TO c##usuario2;
GRANT c##UsuarioFinal_ROL TO c##usuario2;