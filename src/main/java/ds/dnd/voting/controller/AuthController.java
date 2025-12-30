package ds.dnd.voting.controller;

import ds.dnd.voting.dto.LoginRequestDTO;
import ds.dnd.voting.dto.LoginResponseDTO;
import ds.dnd.voting.security.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;

    /**
     * Login endpoint - returns JWT token if credentials are valid
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequestDTO request) {
        try {
            LoginResponseDTO response = authService.login(request);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse(e.getMessage()));
        }
    }

    @lombok.Data
    @lombok.AllArgsConstructor
    public static class ErrorResponse {
        private String error;
    }
}

