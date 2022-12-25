# Описание
Тема проекта - Музыкальный стриминговый сервис
# Запуск
## Чистая БД
По умолчанию.
```
docker-compose build
docker-compose up
```
## Заполненная БД
Поменять в docker.compose строчку в database/volumes с ```- ./db_clean.sql:/docker-entrypoint-initdb.d/db_init.sql``` 
на ```- ./db_filled.sql:/docker-entrypoint-initdb.d/db_init.sql```
```
docker-compose build
docker-compose up
docker cp ./data backend:/backend/
```
