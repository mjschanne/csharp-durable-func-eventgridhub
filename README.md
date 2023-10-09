# csharp-durable-func-eventgridhub
Demonstrating a function chaining durable function written in C# with event grid hub trigger

https://learn.microsoft.com/en-us/azure/event-grid/overview#receive-events-from-azure-services

Event Grid can receive events from 20+ Azure services so that you can automate your operations. For example, you can configure Event Grid to receive an event when a new blob has been created on an Azure Storage Account so that your downstream application can read and process its content. For a list of all supported Azure services and events, see System topics.



Events have the following characteristics:
- An event is a lightweight notification that indicates that something happened.
- The event may be sent to multiple receivers, or to none at all.
- Events are often intended to "fan out," or have a large number of subscribers for each publisher.
- The publisher of the event has no expectation about the action a receiving component takes.
- Some events are discrete units and unrelated to other events.
- Some events are part of a related and ordered series.


Messages are more likely to be used where the distributed application requires a guarantee that the communication will be processed.


Questions to consider:
- required delivery at least once?
- delivery required to be at most once?
- fifo required?



Blob storage (Event Source) -> Event Grid -> Azure Functions (Event Subscriber)
[
  {
    "topic": string,
    "subject": string,
    "id": string,
    "eventType": string,
    "eventTime": string,
    "data":{
      object-unique-to-each-publisher
    },
    "dataVersion": string,
    "metadataVersion": string
  }
]

An event publisher is the user or organization that decides to send events to Event Grid. For example, Microsoft publishes events for several Azure services. You can publish events from your own application. Organizations that host services outside of Azure can publish events through Event Grid. The event source is the specific service generating the event for that publisher.

System topics are built-in topics provided by Azure services. You don't see system topics in your Azure subscription because the publisher owns the topics, but you can subscribe to them. To subscribe, provide information about the resource from which you want to receive events. As long as you have access to the resource, you can subscribe to its events.

Event Subscriptions define which events on a topic an event handler wants to receive. A subscription can also filter events by their type or subject, so you can ensure an event handler only receives relevant events.

An event handler (sometimes referred to as an event "subscriber") is any component (application or resource) that can receive events from Event Grid. For example, Azure Functions can execute code in response to the new song being added to the Blob storage account. Subscribers can decide which events they want to handle and Event Grid will efficiently notify each interested subscriber when a new event is available; no polling required.

Simplicity: It's straightforward to connect sources to subscribers in Event Grid.
Advanced filtering: Subscriptions have close control over the events they receive from a topic.
Fan-out: You can subscribe to an unlimited number of endpoints to the same events and topics.
Reliability: Event Grid retries event delivery for up to 24 hours for each subscription.
Pay-per-event: Pay only for the number of events that you transmit.

what if we want to deliver a large stream of events? In this scenario, Event Grid isn't a great solution because it's designed for one-event-at-a-time delivery. Instead, we need to turn to another Azure service: Event Hubs.

Choose Event Hubs if:
You need to support authenticating a large number of publishers.
You need to save a stream of events to Data Lake or Blob storage.
You need aggregation or analytics on your event stream.
You need reliable messaging or resiliency.


You control the scaling of Event Hubs based on how many throughput units or processing units you purchase. A single throughput unit equates to:

Ingress: Up to 1 MB per second or 1000 events per second (whichever comes first).
Egress: Up to 2 MB per second or 4096 events per second.
Other performance aspects depend on the pricing tier chosen, with basic, standard, premium, and dedicated pricing tiers being available.

Each plan supports different maximum event retention periods – ranging from 24 hours with the basic tier to up to at least 90 days with premium and dedicated tiers. Higher tiers also offer larger storage volumes of up to 10 TB per capacity unit. These tiers also offer different pricing structures for different levels of throughput, numbers of events, and capture functionality. Notably, non-basic tiers provide integration with Apache Kafka and a Schema Registry, which are used by senders and receivers of data to validate data integrity.



Event Hubs uses a pull model that differentiates it from some other messaging services, such as Azure Service Bus Queues. The pull model means that Event Hubs holds the message in its cache and allows it to be read. When a message is read from Event Hubs, it isn't deleted. It's left in the cache, where it can be read, as needed, by more consumers. Messages are deleted from Event Hubs automatically once they've existed in the cache for more than their expiry period. The expiry period, known as time-to-live, is 24 hours by default but is customizable.

This loose coupling means that Event Hubs isn't opinionated about which consumers read its messages. So long as security requirements are met, Azure Active Directory and network configurations are supported, Event Hubs accepts the consumer. This lack of opinionated treatment can mean less time is spent configuring pipelines. But, it also means that there's no built-in mechanism to handle messages that aren't processed as you expect them to be.

For example, imagine that an event is processed but is provided with invalid formatting that causes your consumer function to malfunction. Since Event Hubs is simply acting as a data provider, it doesn't have a built-in mechanism to detect or handle this downstream error and deletes the message once its time-to-live has expired. If processing this data were mission critical, you'd need to make sure you handled the failure some other way, such as exception handling code within the consuming function.

Consideration: this pull model makes it the responsibility of the consumer(s) viz. functions to ensure data is processed before it expires which can mean that messages are lost in exceptional circumstances


Event Hubs traffic is controlled by throughput units. A single throughput unit allows 1 MB per second or 1000 events per second of ingress and twice that amount of egress. Standard Event Hubs can be configured with 1-20 throughput units, and you can purchase more with a quota increase support request. Usage beyond your purchased throughput units is throttled. Event Hubs Capture copies data directly from the internal Event Hubs storage, bypassing throughput unit egress quotas and saving your egress for other processing readers, such as Stream Analytics or Spark.

Azure Event Hubs enables you to automatically capture the streaming data in Event Hubs in an Azure Blob storage or Azure Data Lake Storage account of your choice, with the added flexibility of specifying a time or size interval. Setting up Capture is fast, there are no administrative costs to run it, and it scales automatically with Event Hubs throughput units in the standard tier or processing units in the premium tier.


When you create an event processor, you specify the functions that process events and errors. Each call to the function that processes events delivers a single event from a specific partition. It's your responsibility to handle this event. If you want to make sure the consumer processes every message at least once, you need to write your own code with retry logic. But be cautious about poisoned messages.

We recommend that you do things relatively fast. That is, do as little processing as possible. If you need to write to storage and do some routing, it's better to use two consumer groups and have two event processors.




From what I've seen, the only time you'd want a single partition is when you would like the events to be processed in order. The events are ordered within each partition. The number of partitions does not affect the ingress but it can affect the egress. Example : If you had Azure functions reading from the event hub, the maximum number of instances the functions can scale to will equal the number of partitions. In short, if you want max egress (within the TU), with no concern of ordering, you'd want max partitions.

The shape of the data can influence the partitioning approach. Consider how the downstream architecture will distribute the data when deciding on assignments.
If consumers aggregate data on a certain attribute, you should partition on that attribute, too.
When storage efficiency is a concern, partition on an attribute that concentrates the data to help speed up storage operations.
Ingestion pipelines sometimes shard data to get around problems with resource bottlenecks. In these environments, align the partitioning with how the shards are split in the database.




Use more partitions to achieve more throughput. Each consumer reads from its assigned partition. So with more partitions, more consumers can receive events from a topic at the same time.
Use at least as many partitions as the value of your target throughput in megabytes.

To avoid starving consumers, use at least as many partitions as consumers. For instance, suppose eight partitions are assigned to eight consumers. Any additional consumers that subscribe will have to wait. Alternatively, you can keep one or two consumers ready to receive events when an existing consumer fails.


max(t/p, t/c)

It uses the following values:

t: The target throughput.
p: The production throughput on a single partition.
c: The consumption throughput on a single partition.

For example, consider this situation:

The ideal throughput is 2 MBps. For the formula, t is 2 MBps.
A producer sends events at a rate of 1,000 events per second, making p 1 MBps.
A consumer receives events at a rate of 500 events per second, setting c to 0.5 MBps.

With these values, the number of partitions is 4:

max(t/p, t/c) = max(2/1, 2/0.5) = max(2, 4) = 4

When measuring throughput, keep these points in mind:

The slowest consumer determines the consumption throughput. However, sometimes no information is available about downstream consumer applications. In this case, estimate the throughput by starting with one partition as a baseline. (Use this setup only in testing environments, not in production systems). Event Hubs with Standard tier pricing and one partition should produce throughput between 1 MBps and 20 MBps.

Consumers can consume events from an ingestion pipeline at a high rate only if producers send events at a comparable rate. To determine the total required capacity of the ingestion pipeline, measure the producer's throughput, not just the consumer's.

https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/event-hubs/partitioning-in-event-hubs-and-kafka

Each partition manages its own Azure blob files and optimizes them in the background. A large number of partitions makes it expensive to maintain checkpoint data. The reason is that I/O operations can be time-consuming, and the storage API calls are proportional to the number of partitions.

Each producer for Kafka and Event Hubs stores events in a buffer until a sizeable batch is available or until a specific amount of time passes. Then the producer sends the events to the ingestion pipeline. The producer maintains a buffer for each partition. When the number of partitions increases, the memory requirement of the client also expands. If consumers receive events in batches, they may also face the same issue. When consumers subscribe to a large number of partitions but have limited memory available for buffering, problems can arise.

With more partitions, the load-balancing process has to work with more moving parts and more stress. Transient exceptions can result. These errors can occur when there are temporary disturbances, such as network issues or intermittent internet service. They can appear during an upgrade or load balancing, when Event Hubs sometimes moves partitions to different nodes. Handle transient behavior by incorporating retries to minimize failures.


https://learn.microsoft.com/en-us/azure/architecture/serverless/event-hubs-functions/resilient-design


https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs?tabs=isolated-process%2Cextensionv5&pivots=programming-language-python#hostjson-settings

number of azure function trigger instances = ~num of partitions
max size of events in batch = setting in host json (min 1, default 100, max ???)
batchCheckpointFrequency = (default is 1)


max function length: https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale#timeout unlimited for premium (but only guaranteed for 50 minutes)
premium
    windows: 100 instances
    linux: 20-100 instances


https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale
- different limitations of different hosting plans


