namespace CdcConsumer.Models
{
    public class CdcMessage
    {
        public string? Schema { get; set; }
        public Payload? Payload { get; set; }
    }

    public class Payload
    {
        public string? Op { get; set; }
        public long? TsMs { get; set; }
        public Before? Before { get; set; }
        public After? After { get; set; }
        public Source? Source { get; set; }
        public string? TxId { get; set; }
    }

    public class Before
    {
        public int? CustomerId { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
    }

    public class After : Before
    {
        public long? CreatedDate { get; set; }
        public long? ModifiedDate { get; set; }
    }

    public class Source
    {
        public int? Version { get; set; }
        public string? Connector { get; set; }
        public string? Name { get; set; }
        public long? TsMs { get; set; }
        public string? Snapshot { get; set; }
        public string? Db { get; set; }
        public string? Schema { get; set; }
        public string? Table { get; set; }
        public long? Change_lsn { get; set; }
        public long? Commit_lsn { get; set; }
        public int? Event_serial_no { get; set; }
    }
}
