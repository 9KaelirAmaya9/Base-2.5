import logging
import os
from contextlib import suppress
from uuid import UUID

from celery import Celery

from api.services.email_service import process_outbox_email


logger = logging.getLogger('api.tasks')

# Broker/backends from environment; defaults align with .env.example
BROKER_URL = os.getenv('CELERY_BROKER_URL', 'redis://redis:6379/0')
RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', 'redis://redis:6379/1')

app = Celery(
    'app',
    broker=BROKER_URL,
    backend=RESULT_BACKEND,
    fixups=[],
)

# Basic config can be extended as needed
app.conf.update(
    task_serializer='json',
    result_serializer='json',
    accept_content=['json'],
    timezone='UTC',
    enable_utc=True,
    include=['api.tasks'],
)

# Ensure tasks are registered even when Celery starts before module import.
app.autodiscover_tasks(['api'])


@app.task(name='app.ping')
def ping(request_id: str | None = None):
    with suppress(Exception):
        logger.info('ping', extra={'request_id': request_id})
    return 'pong'


@app.task(name='app.add')
def add(x: int, y: int) -> int:
    return int(x) + int(y)


@app.task(bind=True, name='app.send_email_outbox')
def send_email_outbox(self, outbox_id: str, request_id: str | None = None) -> str:
    with suppress(Exception):
        logger.info(
            'send_email_outbox',
            extra={'task_id': self.request.id, 'request_id': request_id, 'outbox_id': outbox_id},
        )

    process_outbox_email(outbox_id=UUID(outbox_id))
    return outbox_id
