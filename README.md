# Описание
Тема проекта - Музыкальный стриминговый сервис<br>
Внешний вид проекта можно посмотреть в папке ./screenshots<br>
Запускается в докере, по умолчанию на порту 8080<br>
Бэкенд лежит в сабмодуле SNS_backend, фронт и бэк к нему в sns_bff<br>
Дампы БД - db_clean.sql и db_filled.sql
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
