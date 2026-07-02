var app = WebApplication.CreateBuilder(args).Build();
app.MapGet("/health", () => "healthy");
app.Run();
