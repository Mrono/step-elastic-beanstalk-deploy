#Amazon EB deployment for Wercker.com


[![wercker status](https://app.wercker.com/status/ff5cec33194ea3c318288128f970c134/m "wercker status")](https://app.wercker.com/project/bykey/ff5cec33194ea3c318288128f970c134)

> Please note: This requires you to have an already existing Elastic Beanstalk application and environment in place, it will not run a startup procedure.

```yml
deploy:
    steps:
        - mrono/elastic-beanstalk-deploy:
            key: amazon key
            secret_key: amazon secret key
            app_name: EB application name
            env_name: EB environment name
```
