package ds.dnd.voting.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final AuthService authService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String path = request.getRequestURI();
        String method = request.getMethod();

        log.debug("Processing request: {} {}", method, path);

        // Allow CORS preflight requests (OPTIONS) to pass through
        if ("OPTIONS".equalsIgnoreCase(method)) {
            filterChain.doFilter(request, response);
            return;
        }

        // Allow login endpoint and public endpoints without authentication
        if (path.equals("/api/auth/login") ||
            path.startsWith("/h2-console") ||
            path.equals("/api/voting/current-week") ||
            path.equals("/api/voting/current-results") ||
            path.startsWith("/api/voting/week/") ||
            path.equals("/api/voting/past-weeks") ||
            path.equals("/api/voting/all-weeks")) {
            filterChain.doFilter(request, response);
            return;
        }

        // For protected endpoints (voting, reset), require authentication
        if (path.equals("/api/voting/vote") || path.equals("/api/voting/reset-week")) {
            String authHeader = request.getHeader("Authorization");

            log.debug("Auth header present: {}", authHeader != null);

            if (authHeader == null || authHeader.trim().isEmpty()) {
                log.warn("No authorization header for protected endpoint: {}", path);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json");
                response.getWriter().write("{\"error\": \"No authentication token provided\"}");
                return;
            }

            String username = authService.validateTokenAndGetUsername(authHeader);

            if (username == null) {
                log.warn("Invalid or expired token for user attempting to access: {}", path);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json");
                response.getWriter().write("{\"error\": \"Invalid or expired token\"}");
                return;
            }

            log.debug("Authenticated user: {} for path: {}", username, path);
            // Store username in request attribute for use in controller
            request.setAttribute("username", username);
        }

        filterChain.doFilter(request, response);
    }
}

