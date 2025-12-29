package ds.dnd.voting.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Getter
@Setter
@NoArgsConstructor
public class TimeSlot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDateTime datetime;

    @ManyToOne(optional = false)
    @JoinColumn(name = "voting_week_id")
    @JsonIgnore
    private VotingWeek votingWeek;

    public TimeSlot(LocalDateTime datetime, VotingWeek votingWeek) {
        this.votingWeek = votingWeek;
        this.datetime = datetime;
    }
}
