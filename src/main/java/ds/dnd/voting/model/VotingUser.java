package ds.dnd.voting.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "voting_user")
@Getter
@Setter
@NoArgsConstructor
public class VotingUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50, unique = true)
    private String name;

    public VotingUser(String name) {
        this.name = name;
    }
}


