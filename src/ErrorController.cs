using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

[Route("Error")]
public class ErrorController : Controller
{
    private readonly ILogger<ErrorController> _logger;
    public ErrorController(ILogger<ErrorController> logger) => _logger = logger;

    [Route("{statusCode:int}")]
    public IActionResult HttpStatusCodeHandler(int statusCode) => statusCode switch
    {
        404 => View("NotFound"),
        403 => View("Forbidden"),
        _   => View("ServerError")
    };

    [Route("global")]
    public IActionResult GlobalError()
    {
        var feature = HttpContext.Features.Get<IExceptionHandlerPathFeature>();
        var errorId = Guid.NewGuid().ToString("N")[..8].ToUpper();
        if (feature != null)
            _logger.LogError(feature.Error, "Error ID: {ErrorId} | Path: {Path}", errorId, feature.Path);
        ViewBag.ErrorId = errorId;
        Response.StatusCode = 500;
        return View("ServerError");   // generic message + Error ID only, no stack trace
    }
}
