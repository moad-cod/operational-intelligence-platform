1. Accéder à glpi_ocs_db

Ton container source :

glpi_ocs_db
Depuis le terminal Linux
docker exec -it glpi_ocs_db mysql -u mouad -p

Puis :

secret


2. Accéder à warehouse_db

Container :

warehouse_db
Terminal
docker exec -it warehouse_db mysql -u warehouse -p

Password :

warehouse_pass


Entrer dans PostgreSQL
docker exec -it airflow_postgres psql -U airflow
Voir les databases
\l

Utiliser la DB Airflow
\c airflow

Voir les tables
\dt