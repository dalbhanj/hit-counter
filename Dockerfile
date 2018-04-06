FROM python:3.5-onbuild
EXPOSE 80
CMD [ "gunicorn", "app:app", "-b", "0.0.0.0:80" ]
