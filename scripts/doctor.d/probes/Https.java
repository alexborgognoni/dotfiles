// java Https.java <url>: prints "HTTP <status>" when the JDK trusts the site's
// certificate (through the corporate proxy too), the failure and exit 1 when it
// does not. Used by doctor.d/runtimes.sh.
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class Https {
  public static void main(String[] args) {
    try {
      var response =
          HttpClient.newHttpClient()
              .send(
                  HttpRequest.newBuilder(URI.create(args[0])).build(),
                  HttpResponse.BodyHandlers.discarding());
      System.out.println("HTTP " + response.statusCode());
    } catch (Exception e) {
      System.out.println(e.getClass().getSimpleName() + ": " + e.getMessage());
      System.exit(1);
    }
  }
}
