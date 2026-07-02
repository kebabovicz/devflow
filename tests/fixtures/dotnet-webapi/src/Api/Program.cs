var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
var app = builder.Build();
app.UseSwagger();
app.MapGet("/health", () => Results.Ok("healthy"));
app.MapGet("/api/items", () => Results.Ok(new[] { "a", "b" }));
app.Run();
