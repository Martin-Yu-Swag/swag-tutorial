## [First Steps With Celery](https://docs.celeryq.dev/en/stable/getting-started/first-steps-with-celery.html)

### Calling the task

```py
# tasks.py
from celery import Celery

app = Celery('tasks', broker="broker_connecting_string")

@app.task
def add(x,y):
    return x + y

# main.py
from tasks import add
add.delay(4, 4)
# delay = shortcut of apply_async
```

### Keeping Results

- need to set backend string in config or celery constructor

```py
result = add.delay(4, 4)
# result = AsyncResult instance

result.ready()
result.get(timeout=1) # turn result into a sync process
result.get(propagate=False) # dont raise exception
result.traceback # gain the original traceback
```

### Configuration

```py
app.conf.update(**configs)

# some common config to name a few
broker_url        = 'pyamqp://'
result_backend    = 'rpc://'
task_serializer   = 'json'
result_serializer = 'json'
accept_content    = ['json']
timezone          = 'Europe/Oslo'
enable_utc        = True

task_routs = {
    "tasks.add": "low-priority" # to a dedicated queue
}
task_annotations = {
    "tasks.add": {
        "rate_limit": "10/m"    # only 10 tasks of this type can be processed in 1 min
    }
}
task_default_rate_limit = None  # default: No rate limit
```

## [Next Steps](https://docs.celeryq.dev/en/stable/getting-started/next-steps.html)

### Starting the worker

doc demo

```
--------------- celery@halcyon.local v4.0 (latentcall)
--- ***** -----
-- ******* ---- [Configuration]
- *** --- * --- . broker:      amqp://guest@localhost:5672//
- ** ---------- . app:         __main__:0x1012d8590
- ** ---------- . concurrency: 8 (processes)
- ** ---------- . events:      OFF (enable -E to monitor this worker)
- ** ----------
- *** --- * --- [Queues]
-- ******* ---- . celery:      exchange:celery(direct) binding:celery
--- ***** -----

[2012-06-08 16:23:51,078: WARNING/MainProcess] celery@halcyon.local has started.
```

- `Concurrency`
  - number of pre-fork worker process for tasking handling
  - default: # of CPU on machine
  - in addition to default pre-fork pool, also support using Eventlet, Gevent, running a single thread

- `Events` (= worker logs)
  - option that causes Celery to send monitoring msgs for action occurring in the worker.
  - can be used by celery events / Flower (real-time Celery monitory)

- `Queue`
  - list of queues that the worker will consume tasks from.
  - route msg to specific workers as a means for Quality of Service

---

swag worker log:

```
 -------------- celery@worker v5.4.0 (opalescent)
--- ***** ----- 
-- ******* ---- Linux-6.13.7-orbstack-00283-g9d1400e7e9c6-aarch64-with 2025-03-24 09:10:10
- *** --- * --- 
- ** ---------- [config]
- ** ---------- .> app:         __main__:0xffff823005c0
- ** ---------- .> transport:   redis://redis:6379/9
- ** ---------- .> results:     redis://redis:6379/8
- *** --- * --- .> concurrency: 10 (gevent)
-- ******* ---- .> task events: OFF (enable -E to monitor tasks in this worker)
--- ***** ----- 
 -------------- [queues]
                .> celery           exchange=celery(direct) key=celery
                .> swag.ext.affise  exchange=swag.ext.affise(direct) key=swag.ext.affise
                .> swag.ext.aftee   exchange=swag.ext.aftee(direct) key=swag.ext.aftee
                .> swag.ext.axinom  exchange=swag.ext.axinom(direct) key=swag.ext.axinom
# ...
[tasks]
  . swag.auth.signals.track_user_registered
  . swag.auth.tasks.generate_access_token
  . swag.auth.tasks.generate_paired_tokens
  . swag.auth.tasks.generate_refresh_token
# ...
[2025-03-24 09:10:10,217: INFO/MainProcess] Connected to redis://redis:6379/9
[2025-03-24 09:10:10,219: INFO/MainProcess] mingle: searching for neighbors
[2025-03-24 09:10:11,230: INFO/MainProcess] mingle: all alone
[2025-03-24 09:10:11,267: INFO/MainProcess] celery@worker ready
```

### In the background

- `celery multi [command]`: daemonization scripts
  - start
  - restart
  - stop
  - stopwait

```bash
# -A = --app
# -l = --loglevel
# w1 = worker name
celery multi start w1 \
    --app proj \
    --loglevel INFO \
    --pidfile=/var/run/celery/%n.pid \
    --logfile=/var/log/celery/%n%I.log

celery multi start 10 \
    -A proj \
    -l INFO \
    -Q:1-3 images,video \
    -Q:4,5 data \
    -Q default \
    -L:4,5 debug
```

### Calling Tasks

```py
my_task.delay(arg1, arg2)
# equals to
my_task.apply_async((arg1, arg2))

# apply_async allow additional config arg
my_task.apply_async((arg1, arg2), queue='queue.name', countdown=10)
# task will execute, at the earliest, 10 seconds after the message was sent

# directly invoke function will evaluate immediately,
# no task queue would be sent.
my_task(arg1, arg2) # return result
```

- Every task will be given a task id (UUID)

```py
res = add.delay(2, 2)
res.get(timeout=1) # 4
res.id             # task id foYhGn7gT9I1IGbE
res.get(propagate=False)    # return exception instance
res.get(propagate=True)     # raise exception instance
res.failed()
res.successful()
res.state # PENDING -> (STARTED) -> SUCCESS / FAILURE
# STARTED state recorded only if task_track_started is enable
# or @task(track_started=True) option is set
# Tasks with retries:
# PENDING -> STARTED -> RETRY -> STARTED -> RETRY -> STARTED -> SUCCESS
```

### Signature

- wrap the task into a callable partial function with session
- able to pass result to next task signature
- useful in chaining task

```py
sig = add.s(2)      # incomplete partial: add(?, 2)
res = sig.delay(8)  # resolve the partial to add(8, 2)

sig.apply_async(args=(), kwargs={}, **options)
sig.delay(*args, **kwargs)
```

### The Primitive

- group
- map
- starmap
- chain
- chord
- chunks

#### group

- calls a list of tasks in parallel
- returns a special result instance that can inspect results as a group

```py
from celery import group

group(add.s(i, i) for i in range(10))().get()
# [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]

# partial group
group(add.s(i) for i in range(10))(10).get()
# [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
```

- If you call the group, the tasks will be applied **one after another in the current process**

#### chain

> Tasks can be linked together so that after one task returns the other is called

```py
from celery import chain

chain(add.s(4, 4)| mul(8))().get()  # 16
# equals to
(add.s(4,4) | mul(8))().get()

# partial chain
chain(add.s(4) | mul(8))(4).get()
```

#### chord

- a group with callback

```py
from celery import chord, group
from proj.tasks import add, xsum

chord(
    (add.s(i, i) for i in range(10)),
    xsum.s()
)().get()

# A group chained to another task will be converted to a chord automatically
(
    group(add.s(i, i) for i in range(10)) | \
    xsum.s()
)().get()

```

### Routing

- set in config or specify in apply func:

```py
task_routes = {
  'proj.tasks.add': {
    'queue': 'hipri'
  }
}

add.apply_async((2, 2), queue='hipri')
```

- make a worker consume from specific queue

```bash
celery --app proj worker --queue hipri
```

### Remote Control

```bash
# see what tasks the worker is currently working on
celery --app proj inspect active
# implemented by using broadcast messaging

# specify worker host
celery --app proj inspect active --destination=celery@example.com

# control command, which contains commands that actually change things in the worker at runtime
celery --app proj control --help
```

## [Application](https://docs.celeryq.dev/en/stable/userguide/application.html)

### Main Name

> When you send a task message in Celery, that message won’t contain any source code,
> but only the name of the task you want to execute.

> ...every worker maintains a mapping of task names to their actual functions, called the **task registry**

### Laziness

Create a Celery instance will only do following:

1. Create 1 logical clock instance for events
2. Create the task registry
3. Set itself as the current app (but not if the set_as_current argument was disabled)
4. Call the app.on_init() callback (does nothing by default).

### Abstract Task

> If you override the task’s __call__ method, then it’s very important that you also call self.run 
> to execute the body of the task.
> **Do not call super().__call__!!!**.

## [Tasks](https://docs.celeryq.dev/en/stable/userguide/tasks.html)

- Dual roles:
  - define what happens when a task is called (sends a msg)
  - define what happens when a worker receives that message

- every task class has unique name, this name is referenced in msg
  so the worker can find the right function to execute.

- task msg is not removed from queue until that msg has been acknowledged by a worker

- `acks_late`
  - to have the worker acknowledge the message after the task returns instead
  - set True if your task is **idempotent**
  - Work on process level, not worker level:
    - if the worker is terminated, this task will be handled by other worker
    - but if the worker's process that handled the task is terminated (normally or manually),
      task will be assumed as DONE
    - to avoid this -> `task_reject_on_worker_lost=True` 


### Basics

- shared_task

[ref](https://appliku.com/post/celery-shared_task/)

> The "shared_task" decorator allows creation of Celery tasks for reusable apps as it doesn't need the instance of the Celery app.

### Multiple decorators

- must make sure that the task decorator is applied last

### Bound tasks

> A task being bound means the first argument to the task
> will always be the task instance (self), just like Python bound methods:

```py
@app.task(bind=True)
def add(self, x, y):
    logger.info(self.request.id)
```

- Bound tasks are needed for retries (`task.retry()`)

### Names

- Every task must have a unique name
- customize with implementing celery.`gen_task_name` function

### Task Request

- contains information and state related to the currently executing task.

<details>
<summary>Task attributes</summary>

- id: unique id of the executing task
- group: id of group
- chord: id of chord
- correlation_id
- args
- kwargs
- origin: Name of host that sent this task.
- retries: 
- `is_eager`: Set to True if the task is executed locally in the client, not by a worker
  = 直接在 client code 中 apply
- eta: estimated time of arrival, in UTC time
- expires: The original expiry time of the task
- hostname: Node name of the **worker** instance executing the task.
- delivery_info
- reply-to: Name of **queue** to send replies back to
- `called_directly`: true if the task wasn’t executed by the worker
- timelimit: (soft, hard)
- callbacks: list of signatures if this task returns successfully
- errbacks: list of signatures to be called if this task fails.
- utc: Set to true the caller has UTC enabled
- headers
- reply_to
- root_id: root task id (first task in the workflow)
- parent_id: task that called this task
- chain: Reversed list of tasks that form a chain
- properties
- replaced_task_nesting

</details>

- Task apply_async
  send message to queue -> worker receive message -> worker create task and execute

- Task apply
  client create task and execute

- Task call directly
  client execute function, no task will be created

- Call task directly "in" a task
  task instance will be passed in the sub-called task

### Hiding sensitive information in arguments

- set `argsrepr` / `kwargsrepr` to hide sensitive data in log

```py
(
    charge.s(
      account,
      card='1234 5678 1234 5678',
    )
        .set(kwargsrepr=repr({'card': '**** **** **** 5678'}))
        .delay()
)
```

### Retrying

- most used in python try-catch, retry the task if exception raised
- `retry` will send a new message, using the same task-id, and delivered to same queue
- retry will be recorded in a task state
- `max_retries`
- `default_retry_delay`: By default 180 s
- `countdown` in retry: override `default_retry_delay`
- `autoretry_for`: retry without try-catch process
- `retry_backoff=True`: exponential backoff retry
- `retry_backoff_max`: int
- `retry_jitter`: bool

```py
@app.task(bind=True)
def send_twitter_status(self, oauth, tweet):
    try:
        twitter = Twitter(oauth)
        twitter.update_status(tweet)
    except (Twitter.FailWhaleError, Twitter.LoginError) as exc:
        raise self.retry(exc=exc)
        # exc passed for logging and storing task result

@app.task(
    autoretry_for=(Exception,), # retry on any type of exception
    retry_kwargs={'max_retries': 5},
)
def refresh_timeline(user):
    return twitter.refresh_timeline(user)
```

### List of Options

- `Task.serializer`
  - pickle, json, yaml, or any custom serialization

### States

### Result Backends

> To ensure that resources are released, you must eventually call `get()` or `forget()`
> on **EVERY AsyncResult instance** returned after calling a task.

### Built-in States

- PENDING
- STARTED
- SUCCESS
- FAILURE
- RETRY
- REVOKED

### Semipredicates

> There are number of exceptions can be used to signal function to change
> how it treats the return of task.

#### Ignore

- force the worker to ignore the task.
- no state will be recorded for the task, but the message is still acknowledged
- used for 
  1. implement custom revoke-like func
  2. manually store the result of a task

```py
# 1.
@app.task(bind=True)
def some_task(self):
    if redis.ismember('tasks.revoked', self.request.id):
        raise celery.exceptions.Ignore()

# 2.
@app.task(bind=True)
def get_tweets(self, user):
    timeline = twitter.get_timeline(user)
    if not self.request.called_directly:
        self.update_state(state=states.SUCCESS, meta=timeline)
    raise celery.exceptions.Ignore()
```

#### Reject

- to reject the task message using AMQPs basic_reject method
- won’t have any effect unless Task.acks_late is enabled

#### Retry

- raised by the Task.retry method

### Custom task classes

- All tasks inherit the `app.Task` class, the `run()` method becomes the task body

```py
@app.task
def add(x, y):
    return x + y

# Roughly do this under the hood
class _AddTask(app.Task):

    def run(self, x, y):
        return x + y
add = app.tasks[_AddTask.name]
```

#### Instantiation

> A task is not instantiated for every request,
> but is registered in the task registry as a global instance.

-> __init__ only called once per process

eg. cache a database connection

```py
from celery import Task

class DatabaseTask(Task):
    _db = None

    @property
    def db(self):
        if self._db is None:
            self._db = Database.connect()
        return self._db
```

#### Handlers (of tasks)

- before_start
- after_return
- on_failure
- on_retry
- on_success

#### Requests and custom requests

> Upon receiving a msg to run a task,
> the workers creates a **request** to represent such demand.

`celery.app.task.Task.Request`

`on_timeout` / `on_failure`

> Requests are responsible to actually run and trace the task.

eg.

```py
class MyRequest(Request):
    'A minimal custom request to log failures and hard time limits.'

    def on_timeout(self, soft, timeout):
        super(MyRequest, self).on_timeout(soft, timeout)
        if not soft:
           logger.warning(
               'A hard timeout was enforced for task %s',
               self.task.name
           )

    def on_failure(self, exc_info, send_failed_event=True, return_ok=False):
        super().on_failure(
            exc_info,
            send_failed_event=send_failed_event,
            return_ok=return_ok
        )
        logger.warning(
            'Failure detected for task %s',
            self.task.name
        )

class MyTask(Task):
    Request = MyRequest
```

### How it Works

#### Avoid launching synchronous subtasks

```py
# BAD
@app.task
def update_page_info(url):
    page = fetch_page.delay(url).get()
    info = parse_page.delay(page).get()
    store_page_info.delay(url, info)

# GOOD
def update_page_info(url):
    # fetch_page -> parse_page -> store_page
    chain = fetch_page.s(url) | parse_page.s() | store_page_info.s(url)
    chain()

# if really need to run subtasks sync (BUT NOT recommended)
@app.task
def update_page_info(url):
    page = fetch_page.delay(url).get(disable_sync_subtasks=False)
    info = parse_page.delay(page).get(disable_sync_subtasks=False)
    store_page_info.delay(url, info)
```

### Performance and Strategies

Granularity

- overhead of over fine-grained: A message needs to be sent, data may not be local, etc

Data locality

State

- eg. don't pass orm instance in task. Refetch it once task is being executed.

Database transactions

### Example

## [Calling Tasks](https://docs.celeryq.dev/en/stable/userguide/calling.html)

### Basics

- apply_async (send task msg)
- delay (no exec options)
- __call__ -> task will not be executed by a worker, but in the current process instead (a message won’t be sent)

### Linking (callbacks/errbacks)

callback: sent first result to a NEW task.

```py
add.apply_async((2,2), link=add.s(16))
add.apply_async((2, 2), link=[add.s(16), other_task.s()])
```

errback: 
call the errback function directly
so that the raw request, exception and traceback objects can be passed to it

```py
@app.task
def error_handler(request, exc, traceback):
    print('Task {0} raised exception: {1!r}\n{2!r}'.format(
          request.id, exc, traceback))

add.apply_async((2, 2), link_error=error_handler.s())
```

### On message

catching all states changes by setting `on_message` callback

```py
@app.task(bind=True)
def hello(self, a, b):
    time.sleep(1)
    self.update_state(state="PROGRESS", meta={'progress': 50})
    time.sleep(1)
    self.update_state(state="PROGRESS", meta={'progress': 90})
    time.sleep(1)
    return 'hello world: %i' % (a+b)

def on_raw_message(body):
    print(body)

a, b = 1, 1
r = hello.apply_async(args=(a, b))
print(r.get(on_message=on_raw_message, propagate=False))
```

Result

```
{'task_id': '5660d3a3-92b8-40df-8ccc-33a5d1d680d7',
 'result': {'progress': 50},
 'children': [],
 'status': 'PROGRESS',
 'traceback': None}
{'task_id': '5660d3a3-92b8-40df-8ccc-33a5d1d680d7',
 'result': {'progress': 90},
 'children': [],
 'status': 'PROGRESS',
 'traceback': None}
{'task_id': '5660d3a3-92b8-40df-8ccc-33a5d1d680d7',
 'result': 'hello world: 10',
 'children': [],
 'status': 'SUCCESS',
 'traceback': None}
hello world: 10
```

### ETA and Countdown

ETA = estimate time of arrival

- set a specific *date and time* that is the earliest time at which your task will be executed

countdown

a shortcut to set ETA by seconds into the future.

NOTE: 
The task is guaranteed to be executed at some time 
**after** the specified date and time, but not necessarily at that exact time.

WARNING:
- Tasks with eta or countdown are **immediately fetched** by the worker
- they reside in the worker’s memory until the scheduled time passes
- using eta and countdown is **not recommended** for scheduling tasks for a distant future

### Expiration

`expires`
- seconds to expire after task execution, or
- specific datetime of expiration
- if worker receives an expired task -> mark task as REVOKED

### Message Sending Retry

- auto retry sending msg in the event of conn failure
- retry behavior can be configured
- `add.apply_async((2, 2), retry=False)`
- config:
  - `task_publish_retry`
  - `task_publish_retry_policy`
    - `max_reties`
    - `interval_start`
    - `interval_step`
    - `interval_max`
    - `retry_errors`: tuple of exception class that should be retry

### [Connection Error Handling](https://docs.celeryq.dev/en/stable/userguide/calling.html#connection-error-handling)

- raise `OperationalError`

### [Serializers](https://docs.celeryq.dev/en/stable/userguide/calling.html#serializers)

> Data transferred between clients and workers needs to be serialized,
> so every message in Celery has a **`content_type`** header that describes the serialization method used to encode it.

- config: `task_serializer`
- options:
  - json (default)
  - pickle
    - support of all built-in python data types
    - smaller msg when sending binary files
    - slight speedup over json
  - YAML
  - msgpack
    - binary serialization format closer to JSON
    - compress better, parse faster

### [Compression](https://docs.celeryq.dev/en/stable/userguide/calling.html#compression)

Can compress msg with following builtin schemes

- brotli
- bzip2 - smaller in size but slower
- gzip
- lzma
- zlib
- zstd

### [Connections](https://docs.celeryq.dev/en/stable/userguide/calling.html#connections)

### [Routing options](https://docs.celeryq.dev/en/stable/userguide/calling.html#routing-options)

- Can route tasks to different queues.

### [Result options](https://docs.celeryq.dev/en/stable/userguide/calling.html#result-options)

- `task_ignore_result`
- `ignore_result`
- `result_extended`: store additional metadata about task

#### Advanced Options:

- `exchange`: Name of exchange (or a kombu.entity.Exchange) to send the message to
- `routing_key`: Routing key used to determine
- `priority`: # between 0 ~ 255 (0 is highest)

---

## [Canvas: Designing Work-flows](https://docs.celeryq.dev/en/stable/userguide/canvas.html)

### [Signatures](https://docs.celeryq.dev/en/stable/userguide/canvas.html#signatures)

- `s()` support kwargs
- You can't define options wih `s()` (s is shortcut of delay),
  but can chaining options with `set()`

```py
add.s(2, 2, debug=True)
# equals to
s = add.signature((2,2), {"debug": True}, countdown=1)
s.kwargs
s.options

add.s(2, 2).set(countdown=1)
# equals to
add.signature((2,2), countdown=1)
```

#### Partial

- Also support signature cloning

```py
s = add.s(2)
clone_s = s.clone(args=(4,), kwargs={'debug': True})
# add(4, 2, debug=True)
```

#### Immutability

- immutable signature wont accept any parameters
  (so the it cant be partial signature)

```py
add.apply_async((2, 2), link=reset_buffer.signature(immutable=True))
# equals to
add.apply_async((2, 2), link=reset_buffer.si())
```

#### Callbacks

- Use `link` when you don't care about the result of the task

### Primitive

#### group

#### chain

```py
res = (add.si(2, 2) | add.si(4, 4) | add.si(8, 8))()
res.get()
# 16
res.parent.get()
# 8
res.parent.parent.get()
# 4
```

- with link:

```py
res = add.apply_async((2, 2), link=mul.s(16))
res.get()
# 4, which is the result of parent

res.children
# [<AsyncResult: 8c350acf-519d-4553-8a53-4ad3a5c5aeb4>]
res.children[0].get()
# 64

list(res.collect())
# [(<AsyncResult: 7b720856-dc5f-4415-9134-5c89def5664e>, 4),
#  (<AsyncResult: 8c350acf-519d-4553-8a53-4ad3a5c5aeb4>, 64)]

# chain multiple
s = add.s(2, 2)
s.link(mul.s(4))
s.link(log_result.s())

# on_error
add.s(2, 2).on_error(log_error.s()).delay()
# equals to
add.apply_async((2, 2), link_error=log_error.s())
```

- A chain will inherit the task id of the **last task in the chain**.

#### graph

```py
res = chain(add.s(4, 4), mul.s(8), mul.s(10))()

res.parent.parent.graph
# 285fa253-fcf8-42ef-8b95-0078897e83e6(1)
#     463afec2-5ed4-4036-b22d-ba067ec64f52(0)
# 872c3995-6fa0-46ca-98c2-5a19155afcf0(2)
#     285fa253-fcf8-42ef-8b95-0078897e83e6(1)
#         463afec2-5ed4-4036-b22d-ba067ec64f52(0)
```

#### chords

- add a callback to be called when all of the tasks in a group have finished executing

#### Map

- `map` diff from group:
  - only 1 task message is sent
  - the operation is sequential

```py
task.map([1, 2])
# equals to

res = [task(1), task(2)]
```

#### Starmap

arguments are applied as *args

```py
add.starmap([(2, 2), (4, 4)])
# equals to

res = [add(2, 2), add(4, 4)]
```

#### Chunks

- splits a long list of arguments into part

```py
res = add.chunks(zip(range(100), range(100)), 10)()
res.get()
# [[0, 2, 4, 6, 8, 10, 12, 14, 16, 18],
#  [20, 22, 24, 26, 28, 30, 32, 34, 36, 38],
#  [40, 42, 44, 46, 48, 50, 52, 54, 56, 58],
#  [60, 62, 64, 66, 68, 70, 72, 74, 76, 78],
#  [80, 82, 84, 86, 88, 90, 92, 94, 96, 98],
#  [100, 102, 104, 106, 108, 110, 112, 114, 116, 118],
#  [120, 122, 124, 126, 128, 130, 132, 134, 136, 138],
#  [140, 142, 144, 146, 148, 150, 152, 154, 156, 158],
#  [160, 162, 164, 166, 168, 170, 172, 174, 176, 178],
#  [180, 182, 184, 186, 188, 190, 192, 194, 196, 198]]
```

### Stamping

- prerequisite: `result_extended=True`
- give an ability to label the signature and its components for debugging information purposes

```py
sig1 = add.si(2, 2)
sig1_res = sig1.freeze()
g = group(sig1, add.si(3, 3))
g.stamp(stamp='your_custom_stamp')
res = g.apply_async()
res.get(timeout=TIMEOUT)
# [4, 6]
sig1_res._get_task_meta()['stamp']
# ['your_custom_stamp']
```

---
