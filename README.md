step-elastic-beanstalk-deploy
=============================
#This requires you to have an already existing Elastic Beanstalk application and environment in place, it will not run a startup procedure.

```yml
deploy:
    steps:
        - mrono/elastic-beanstalk-deploy:
            key: amazon key
            secret_key: amazon secret key
            app_name: EB application name
            env_name: EB environment name
```
