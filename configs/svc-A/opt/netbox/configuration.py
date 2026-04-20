ALLOWED_HOSTS = ['10.10.10.20', 'svc-a.cia.lab', 'localhost', '127.0.0.1']

DATABASE = {
    'NAME': 'netbox',
    'USER': 'netbox',
    'PASSWORD': 'REDACTED_SEE_VAULT',
    'HOST': 'localhost',
    'PORT': '',
    'CONN_MAX_AGE': 300,
}

REDIS = {
    'tasks': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': 'REDACTED_SEE_VAULT',
        'DATABASE': 0,
        'SSL': False,
    },
    'caching': {
        'HOST': 'localhost',
        'PORT': 6379,
        'PASSWORD': 'REDACTED_SEE_VAULT',
        'DATABASE': 1,
        'SSL': False,
    }
}

SECRET_KEY = 'REDACTED_SEE_VAULT'




# API token security (NetBox 4.3+)
API_TOKEN_PEPPERS = {
    0: 'REDACTED_SEE_VAULT',
}
