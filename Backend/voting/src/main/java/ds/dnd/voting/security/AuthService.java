package ds.dnd.voting.security;

import ds.dnd.voting.dto.LoginRequestDTO;
import ds.dnd.voting.dto.LoginResponseDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final JwtService jwtService;

    @Value("${app.voting.password}")
    private String votingPassword;

    /**
     * Authenticate user with fixed password
     * Returns JWT token if successful
     */
    public LoginResponseDTO login(LoginRequestDTO request) {
        String username = request.getUsername();
        String password = request.getPassword();

        // Validate username (not empty, no special characters for security)
        if (username == null || username.trim().isEmpty()) {
            throw new RuntimeException("Username cannot be empty");
        }

        if (username.length() > 50) {
            throw new RuntimeException("Username too long");
        }

        // Check password
        if (!votingPassword.equals(password)) {
            log.warn("Failed login attempt for username: {}", username);
            throw new RuntimeException("Invalid password");
        }

        // Generate token
        String token = jwtService.generateToken(username);

        log.info("Successful login for user: {}", username);

        return new LoginResponseDTO(
                token,
                username,
                "Login successful"
        );
    }

    /**
     * Validate token and extract username
     */
    public String validateTokenAndGetUsername(String token) {
        if (token == null || token.trim().isEmpty()) {
            return null;
        }

        // Remove "Bearer " prefix if present
        if (token.startsWith("Bearer ")) {
            token = token.substring(7);
        }

        if (!jwtService.validateToken(token)) {
            return null;
        }

        return jwtService.getUsernameFromToken(token);
    }
}

